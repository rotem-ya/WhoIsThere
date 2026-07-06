import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/economy_config.dart';
import '../models/economy/economy_transaction_model.dart';
import '../models/economy/match_reward_breakdown.dart';
import '../models/economy/user_economy_model.dart';
import 'local_economy_cache.dart';
import 'qa_logger_service.dart';
import 'reward_calculator.dart';

class EconomyService {
  final FirebaseFirestore _db;
  final LocalEconomyCache? _cache;
  static const _uuid = Uuid();

  EconomyService(this._db, [this._cache]);

  // ── Firestore paths ───────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _db.doc('users/$uid/economy/wallet');

  DocumentReference<Map<String, dynamic>> _exposureRef(String uid) =>
      _db.doc('users/$uid/exposure_history/data');

  CollectionReference<Map<String, dynamic>> _txCol(String uid) =>
      _db.collection('users/$uid/economy_transactions');

  // ── Read ──────────────────────────────────────────────────────

  Stream<UserEconomyModel> walletStream(String uid) {
    return _walletRef(uid).snapshots().map((snap) {
      if (!snap.exists) return UserEconomyModel.empty(uid);
      final model = UserEconomyModel.fromFirestore(uid, snap.data()!);
      _cache?.setCoins(model.coins);
      return model;
    });
  }

  Future<UserEconomyModel> getWallet(String uid) async {
    final snap = await _walletRef(uid).get();
    if (!snap.exists) return UserEconomyModel.empty(uid);
    return UserEconomyModel.fromFirestore(uid, snap.data()!);
  }

  // ── Initialise new user ───────────────────────────────────────

  /// Returns true the ONE time coins are first granted (first install).
  Future<bool> initWallet(String uid) async {
    final ref = _walletRef(uid);
    bool granted = false;
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          final existing = UserEconomyModel.fromFirestore(
              uid, snap.data() as Map<String, dynamic>);
          if (existing.totalEarned > 0) return;
          tx.update(ref, {
            'coins': FieldValue.increment(EconomyConfig.initialCoins),
            'totalEarned': EconomyConfig.initialCoins,
          });
        } else {
          final wallet = UserEconomyModel.empty(uid).copyWith(
            coins: EconomyConfig.initialCoins,
            totalEarned: EconomyConfig.initialCoins,
          );
          tx.set(ref, wallet.toFirestore());
        }
        granted = true;
      });
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('ECONOMY', 'INIT_WALLET_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
    }
    if (granted) {
      QaLoggerService.instance.log('ECONOMY', 'INIT_WALLET_GRANTED uid=${uid.substring(0, uid.length.clamp(0, 8))}');
      await _cache?.setCoins(EconomyConfig.initialCoins);
    }
    return granted;
  }

  // ── Match reward — only writes to the calling user's wallet ───

  Future<int> _getExposureCount(String uid, String imageId) async {
    try {
      final snap =
          await _exposureRef(uid).get().timeout(const Duration(seconds: 8));
      if (!snap.exists) return 0;
      return (snap.data()?[imageId] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<MatchRewardBreakdown> applyMatchReward({
    required String uid,
    required bool isWin,
    required bool isSolo,
    required int tilesRevealedCount,
    required int totalTilesCount,
    required int wrongGuessCount,
    required Duration timeTaken,
    String? roomId,
    String? imageId,
  }) async {
    final exposureCount = imageId != null
        ? await _getExposureCount(uid, imageId)
        : 0;
    QaLoggerService.instance.log('ECONOMY', 'REWARD_EXPO_OK count=$exposureCount');

    final breakdown = RewardCalculator.calculateMatchReward(
      isWin: isWin,
      isSolo: isSolo,
      tilesRevealedCount: tilesRevealedCount,
      totalTilesCount: totalTilesCount,
      wrongGuessCount: wrongGuessCount,
      timeTaken: timeTaken,
      imageExposureCount: exposureCount,
    );

    if (breakdown.total > 0) {
      await _applyDelta(
        uid: uid,
        delta: breakdown.total,
        type: isWin ? TransactionType.matchWin : TransactionType.matchParticipation,
        roomId: roomId,
        meta: {
          'earlyGuessBonus': breakdown.earlyGuessBonus,
          'speedBonus': breakdown.speedBonus,
          'noWrongGuessBonus': breakdown.noWrongGuessBonus,
          'perfectRoundBonus': breakdown.perfectRoundBonus,
          'wrongGuessPenalty': breakdown.wrongGuessPenalty,
          'tilesRevealed': tilesRevealedCount,
          'totalTiles': totalTilesCount,
          'revealRatio': breakdown.revealRatio,
          'wrongGuessCount': wrongGuessCount,
          'secondsTaken': timeTaken.inSeconds,
        },
        statUpdater: (w) => w.copyWith(
          totalMatchesPlayed: w.totalMatchesPlayed + 1,
          totalMatchesWon: isWin ? w.totalMatchesWon + 1 : null,
        ),
      );
      QaLoggerService.instance.log('ECONOMY', 'REWARD_DELTA_OK delta=${breakdown.total}');
    }

    return breakdown;
  }

  // ── Daily reward ──────────────────────────────────────────────

  /// Returns the breakdown if the reward was granted, or null if already claimed today.
  Future<({int coins, int streak})?> claimDailyReward(String uid) async {
    final now = DateTime.now().toUtc();
    final ref = _walletRef(uid);

    ({int coins, int streak})? result;

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final wallet = snap.exists
            ? UserEconomyModel.fromFirestore(uid, snap.data()!)
            : UserEconomyModel.empty(uid);

        // Guard: already claimed today (UTC)
        final last = wallet.lastDailyRewardAt;
        if (last != null) {
          final sameDay = last.year == now.year &&
              last.month == now.month &&
              last.day == now.day;
          if (sameDay) {
            QaLoggerService.instance.log('ECONOMY', 'DAILY_REWARD_ALREADY_CLAIMED');
            return;
          }
        }

        final newStreak = RewardCalculator.computeNewStreak(
          wallet.dailyStreak,
          wallet.lastDailyRewardAt,
          now,
        );
        final coins = RewardCalculator.calculateDailyReward(newStreak);

        final updated = wallet.copyWith(
          coins: wallet.coins + coins,
          totalEarned: wallet.totalEarned + coins,
          dailyStreak: newStreak,
          lastDailyRewardAt: now,
        );
        tx.set(ref, updated.toFirestore());

        final txId = _uuid.v4();
        tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
          id: txId,
          type: TransactionType.dailyReward,
          delta: coins,
          balanceAfter: updated.coins,
          createdAt: now,
          meta: {'streak': newStreak},
        ).toFirestore());

        result = (coins: coins, streak: newStreak);
      });
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('ECONOMY', 'DAILY_REWARD_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      rethrow;
    }

    if (result != null) {
      await _syncCache(uid);
      await _cache?.setLastDailyRewardDate(now);
    }

    return result;
  }

  /// Doubles today's daily reward after watching a rewarded ad. Grants the
  /// same amount the daily claim paid (recomputed from the wallet's streak).
  /// Idempotent per UTC day via the raw `dailyDoubledAt` wallet field, and
  /// only allowed after today's reward was actually claimed.
  Future<int?> doubleDailyReward(String uid) async {
    final now = DateTime.now().toUtc();
    final ref = _walletRef(uid);
    int? granted;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final wallet = UserEconomyModel.fromFirestore(uid, data);

      bool sameUtcDay(DateTime? d) =>
          d != null && d.year == now.year && d.month == now.month && d.day == now.day;

      // Must have claimed today's reward, and not doubled it yet.
      if (!sameUtcDay(wallet.lastDailyRewardAt)) return;
      final doubledAt = (data['dailyDoubledAt'] as Timestamp?)?.toDate().toUtc();
      if (sameUtcDay(doubledAt)) return;

      // The claim already advanced dailyStreak to today's value.
      final coins = RewardCalculator.calculateDailyReward(wallet.dailyStreak);

      final updated = wallet.copyWith(
        coins: wallet.coins + coins,
        totalEarned: wallet.totalEarned + coins,
      );
      final out = updated.toFirestore();
      out['dailyDoubledAt'] = Timestamp.fromDate(now);
      tx.set(ref, out);

      final txId = _uuid.v4();
      tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
        id: txId,
        type: TransactionType.adReward,
        delta: coins,
        balanceAfter: updated.coins,
        createdAt: now,
        meta: {'reason': 'daily_double', 'streak': wallet.dailyStreak},
      ).toFirestore());

      granted = coins;
    });

    if (granted != null) {
      QaLoggerService.instance.log('ECONOMY', 'DAILY_DOUBLE_GRANTED +$granted');
      await _syncCache(uid);
    }
    return granted;
  }

  // ── Ad reward ─────────────────────────────────────────────────

  Future<bool> applyAdReward(String uid) async {
    final now = DateTime.now().toUtc();
    final ref = _walletRef(uid);
    bool granted = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final wallet = snap.exists
          ? UserEconomyModel.fromFirestore(uid, snap.data()!)
          : UserEconomyModel.empty(uid);

      // Reset counter if we're in a new UTC day
      final windowStart = wallet.adRewardWindowStart;
      final sameDay = windowStart != null &&
          windowStart.year == now.year &&
          windowStart.month == now.month &&
          windowStart.day == now.day;

      final countToday = sameDay ? wallet.adRewardsTodayCount : 0;
      if (countToday >= EconomyConfig.maxAdRewardsPerDay) return;

      const coins = EconomyConfig.adRewardCoins;
      final updated = wallet.copyWith(
        coins: wallet.coins + coins,
        totalEarned: wallet.totalEarned + coins,
        adRewardsTodayCount: countToday + 1,
      );
      final data = updated.toFirestore();
      data['adRewardWindowStart'] =
          Timestamp.fromDate(sameDay ? windowStart : now);
      tx.set(ref, data);

      final txId = _uuid.v4();
      tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
        id: txId,
        type: TransactionType.adReward,
        delta: coins,
        balanceAfter: updated.coins,
        createdAt: now,
        meta: {'adsToday': countToday + 1},
      ).toFirestore());

      granted = true;
    });

    if (granted) await _syncCache(uid);
    return granted;
  }

  // ── Free-entry safety net ─────────────────────────────────────
  // One free game per UTC day when the player can't afford the entry fee. We
  // top the wallet up by exactly the entry fee (not counted as totalEarned) and
  // stamp lastFreeEntryAt, so the normal entry-fee deduction nets to free. This
  // keeps the player out of a coin dead-end without touching the fee pipeline.

  static bool freeEntryAvailable(UserEconomyModel? wallet) {
    final last = wallet?.lastFreeEntryAt;
    if (last == null) return true;
    final now = DateTime.now().toUtc();
    return !(last.year == now.year &&
        last.month == now.month &&
        last.day == now.day);
  }

  /// Grants a one-off coin bonus for watching a rewarded ad on the win screen
  /// (e.g. doubling the coins just earned this match). Not subject to the daily
  /// ad-reward cap because it is naturally gated by finishing a match.
  Future<bool> applyAdBonus(String uid, int amount) async {
    if (amount <= 0) return false;
    await _applyDelta(
      uid: uid,
      delta: amount,
      type: TransactionType.adReward,
      meta: {'adBonus': amount},
    );
    return true;
  }

  /// Grants one free entry (tops up by the entry fee) if not already used today.
  /// Returns true if granted.
  Future<bool> claimFreeEntry(String uid) async {
    final now = DateTime.now().toUtc();
    final ref = _walletRef(uid);
    bool granted = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final wallet = snap.exists
          ? UserEconomyModel.fromFirestore(uid, snap.data()!)
          : UserEconomyModel.empty(uid);

      if (!freeEntryAvailable(wallet)) return;

      const coins = EconomyConfig.gameEntryFee;
      final updated = wallet.copyWith(
        coins: wallet.coins + coins,
        lastFreeEntryAt: now,
      );
      tx.set(ref, updated.toFirestore());

      final txId = _uuid.v4();
      tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
        id: txId,
        type: TransactionType.freeEntry,
        delta: coins,
        balanceAfter: updated.coins,
        createdAt: now,
        meta: const {'freeEntry': true},
      ).toFirestore());

      granted = true;
    });

    if (granted) {
      await _syncCache(uid);
      QaLoggerService.instance.log('ECONOMY', 'FREE_ENTRY_GRANTED uid=${uid.substring(0, uid.length.clamp(0, 6))}');
    }
    return granted;
  }

  // ── Spend coins (hints etc.) ──────────────────────────────────

  /// Returns false if the user doesn't have enough coins.
  Future<bool> spendCoins({
    required String uid,
    required int amount,
    required TransactionType type,
    String? roomId,
    Map<String, dynamic> meta = const {},
  }) async {
    assert(amount > 0, 'amount must be positive');
    bool success = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(_walletRef(uid));
      final wallet = snap.exists
          ? UserEconomyModel.fromFirestore(uid, snap.data()!)
          : UserEconomyModel.empty(uid);

      if (wallet.coins < amount) return;

      final updated = wallet.copyWith(
        coins: wallet.coins - amount,
        totalSpent: wallet.totalSpent + amount,
        totalHintsUsed: type == TransactionType.hintRevealTile ||
                type == TransactionType.hintExtraGuess
            ? wallet.totalHintsUsed + 1
            : null,
      );
      tx.set(_walletRef(uid), updated.toFirestore());

      final txId = _uuid.v4();
      tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
        id: txId,
        type: type,
        delta: -amount,
        balanceAfter: updated.coins,
        roomId: roomId,
        createdAt: DateTime.now().toUtc(),
        meta: meta,
      ).toFirestore());

      success = true;
    });

    if (success) await _syncCache(uid);
    return success;
  }

  // ── Stun card purchase ────────────────────────────────────────

  Future<bool> buyStunCard(String uid) async {
    const price = EconomyConfig.stunCardPrice;
    final success = await spendCoins(
      uid: uid,
      amount: price,
      type: TransactionType.stunCardPurchase,
    );
    if (success) {
      await _db.doc('users/$uid').update({'stunCardCount': FieldValue.increment(1)});
      QaLoggerService.instance.log('ECONOMY', 'STUN_CARD_PURCHASED uid=${uid.substring(0, uid.length.clamp(0, 6))} price=$price');
    }
    return success;
  }

  // ── Guess-block & blackout card purchases ─────────────────────

  Future<bool> buyGuessBlock5Card(String uid) async {
    const price = EconomyConfig.guessBlock5Price;
    final success = await spendCoins(uid: uid, amount: price, type: TransactionType.guessBlock5Purchase);
    if (success) {
      await _db.doc('users/$uid').update({'guessBlock5Count': FieldValue.increment(1)});
      QaLoggerService.instance.log('ECONOMY', 'GUESS_BLOCK5_PURCHASED uid=${uid.substring(0, uid.length.clamp(0, 6))}');
    }
    return success;
  }

  Future<bool> buyGuessBlock10Card(String uid) async {
    const price = EconomyConfig.guessBlock10Price;
    final success = await spendCoins(uid: uid, amount: price, type: TransactionType.guessBlock10Purchase);
    if (success) {
      await _db.doc('users/$uid').update({'guessBlock10Count': FieldValue.increment(1)});
      QaLoggerService.instance.log('ECONOMY', 'GUESS_BLOCK10_PURCHASED uid=${uid.substring(0, uid.length.clamp(0, 6))}');
    }
    return success;
  }

  Future<bool> buyBlackoutCard(String uid) async {
    const price = EconomyConfig.blackoutCardPrice;
    final success = await spendCoins(uid: uid, amount: price, type: TransactionType.blackoutCardPurchase);
    if (success) {
      await _db.doc('users/$uid').update({'blackoutCardCount': FieldValue.increment(1)});
      QaLoggerService.instance.log('ECONOMY', 'BLACKOUT_CARD_PURCHASED uid=${uid.substring(0, uid.length.clamp(0, 6))}');
    }
    return success;
  }

  Future<bool> buyPeekCard(String uid) async {
    const price = EconomyConfig.peekCardPrice;
    final success = await spendCoins(uid: uid, amount: price, type: TransactionType.peekCardPurchase);
    if (success) {
      await _db.doc('users/$uid').update({'peekCardCount': FieldValue.increment(1)});
      QaLoggerService.instance.log('ECONOMY', 'PEEK_CARD_PURCHASED uid=${uid.substring(0, uid.length.clamp(0, 6))}');
    }
    return success;
  }

  /// Atomically consumes one peek card from [uid]'s inventory (no coin cost).
  /// Returns true only when a card was actually decremented.
  Future<bool> consumePeekCard(String uid) async {
    bool consumed = false;
    try {
      await _db.runTransaction((tx) async {
        final ref = _db.doc('users/$uid');
        final snap = await tx.get(ref);
        final count = (snap.data()?['peekCardCount'] as int?) ?? 0;
        if (count <= 0) return;
        tx.update(ref, {'peekCardCount': FieldValue.increment(-1)});
        consumed = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('ECONOMY', 'PEEK_CARD_CONSUME_ERROR $e');
    }
    return consumed;
  }

  // ── Private helpers ───────────────────────────────────────────

  Future<void> _applyDelta({
    required String uid,
    required int delta,
    required TransactionType type,
    String? roomId,
    Map<String, dynamic> meta = const {},
    UserEconomyModel Function(UserEconomyModel)? statUpdater,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_walletRef(uid));
      UserEconomyModel wallet = snap.exists
          ? UserEconomyModel.fromFirestore(uid, snap.data()!)
          : UserEconomyModel.empty(uid);

      wallet = wallet.copyWith(
        coins: wallet.coins + delta,
        totalEarned: delta > 0 ? wallet.totalEarned + delta : null,
        totalSpent: delta < 0 ? wallet.totalSpent + (-delta) : null,
      );
      if (statUpdater != null) wallet = statUpdater(wallet);

      tx.set(_walletRef(uid), wallet.toFirestore());

      final txId = _uuid.v4();
      tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
        id: txId,
        type: type,
        delta: delta,
        balanceAfter: wallet.coins,
        roomId: roomId,
        createdAt: now,
        meta: meta,
      ).toFirestore());
    });

    await _syncCache(uid);
  }

  /// Grants difficulty-scaled coins to a guardian-client who unblocked a stuck human turn.
  /// Idempotent: uses roomId+deadline+actorUid as document key, so retries are safe.
  /// Returns true only when coins are newly granted.
  Future<bool> applyStabilityCompensation({
    required String actorUid,
    required String roomId,
    required int deadline,
    required int amount,
  }) async {
    assert(amount > 0, 'amount must be positive');
    if (actorUid.startsWith('virtual_')) return false;

    final idempotencyKey = 'guardian_${roomId}_${deadline}_$actorUid';
    final txDocRef = _txCol(actorUid).doc(idempotencyKey);
    bool applied = false;

    await _db.runTransaction((tx) async {
      final existing = await tx.get(txDocRef);
      if (existing.exists) return;

      final walletSnap = await tx.get(_walletRef(actorUid));
      final wallet = walletSnap.exists
          ? UserEconomyModel.fromFirestore(actorUid, walletSnap.data()!)
          : UserEconomyModel.empty(actorUid);

      final updated = wallet.copyWith(
        coins: wallet.coins + amount,
        totalEarned: wallet.totalEarned + amount,
      );
      tx.set(_walletRef(actorUid), updated.toFirestore());
      tx.set(txDocRef, EconomyTransactionModel(
        id: idempotencyKey,
        type: TransactionType.stabilityCompensation,
        delta: amount,
        balanceAfter: updated.coins,
        roomId: roomId,
        createdAt: DateTime.now().toUtc(),
        meta: {'deadline': deadline, 'reason': 'guardian_timeout', 'amount': amount},
      ).toFirestore());

      applied = true;
    });

    if (applied) await _syncCache(actorUid);
    return applied;
  }

  Future<void> awardPotWin({
    required String uid,
    required int amount,
    required String roomId,
  }) async {
    if (amount <= 0) return;
    await _applyDelta(
      uid: uid,
      delta: amount,
      type: TransactionType.potWin,
      roomId: roomId,
      meta: {'potAmount': amount},
    );
  }

  Future<void> awardPotRefund({
    required String uid,
    required int amount,
    required String roomId,
  }) async {
    if (amount <= 0) return;
    await _applyDelta(
      uid: uid,
      delta: amount,
      type: TransactionType.potRefund,
      roomId: roomId,
      meta: {'refundAmount': amount},
    );
  }

  Future<void> _syncCache(String uid) async {
    final snap = await _walletRef(uid).get();
    if (!snap.exists) return;
    final coins = (snap.data()!['coins'] as num? ?? 0).toInt();
    await _cache?.setCoins(coins);
  }
}
