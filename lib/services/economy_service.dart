import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/economy_config.dart';
import '../models/economy/economy_transaction_model.dart';
import '../models/economy/match_reward_breakdown.dart';
import '../models/economy/user_economy_model.dart';
import 'local_economy_cache.dart';
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
      _db.doc('users/$uid/exposure_history');

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

  Future<void> initWallet(String uid) async {
    final ref = _walletRef(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      final wallet = UserEconomyModel.empty(uid).copyWith(
        coins: EconomyConfig.initialCoins,
        totalEarned: EconomyConfig.initialCoins,
      );
      tx.set(ref, wallet.toFirestore());
    });
    await _cache?.setCoins(EconomyConfig.initialCoins);
  }

  // ── Match reward — only writes to the calling user's wallet ───

  Future<int> _getExposureCount(String uid, String imageId) async {
    try {
      final snap = await _exposureRef(uid).get();
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
    }

    return breakdown;
  }

  // ── Daily reward ──────────────────────────────────────────────

  /// Returns the breakdown if the reward was granted, or null if already claimed today.
  Future<({int coins, int streak})?> claimDailyReward(String uid) async {
    final now = DateTime.now().toUtc();
    final ref = _walletRef(uid);

    ({int coins, int streak})? result;

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
        if (sameDay) return; // already claimed
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

    if (result != null) {
      await _syncCache(uid);
      await _cache?.setLastDailyRewardDate(now);
    }

    return result;
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
          Timestamp.fromDate(sameDay ? windowStart! : now);
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

  Future<void> _syncCache(String uid) async {
    final snap = await _walletRef(uid).get();
    if (!snap.exists) return;
    final coins = (snap.data()!['coins'] as num? ?? 0).toInt();
    await _cache?.setCoins(coins);
  }
}
