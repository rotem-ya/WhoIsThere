import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/economy/economy_transaction_model.dart';
import '../models/economy/user_economy_model.dart';
import 'qa_logger_service.dart';

/// A weekly leaderboard entry (one per player per ISO week).
class WeeklyEntry {
  final String uid;
  final String name;
  final String? photoUrl;
  final int points;

  const WeeklyEntry({
    required this.uid,
    required this.name,
    this.photoUrl,
    required this.points,
  });

  factory WeeklyEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    return WeeklyEntry(
      uid: d.id,
      name: (m['name'] as String?)?.trim().isNotEmpty == true
          ? m['name'] as String
          : 'שחקן',
      photoUrl: m['photoUrl'] as String?,
      points: (m['points'] as num? ?? 0).toInt(),
    );
  }
}

/// A global weekly leaderboard with no server cron: each ISO week is its own
/// `leaderboards/weekly_{weekKey}/entries` collection, so a new week starts
/// clean and old weeks stay readable for "last week's winners". Every client
/// writes only its own entry (self-write rule); ranking reads are open to any
/// signed-in user. Prize claiming for last week's top 3 is idempotent per user.
class WeeklyLeaderboardService {
  final FirebaseFirestore _db;
  WeeklyLeaderboardService(this._db);

  // Prizes for last week's podium (game coins, client-trusted like the rest of
  // the economy). 1st / 2nd / 3rd.
  static const List<int> podiumRewards = [100, 50, 25];

  // ── Week keys ───────────────────────────────────────────────────────────
  static int _isoWeek(DateTime d) {
    final date = DateTime.utc(d.year, d.month, d.day);
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    return (thursday.difference(firstDay).inDays / 7).floor() + 1;
  }

  static String weekKey([DateTime? now]) {
    final d = (now ?? DateTime.now()).toUtc();
    final date = DateTime.utc(d.year, d.month, d.day);
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final week = _isoWeek(d).toString().padLeft(2, '0');
    return '${thursday.year}-W$week';
  }

  static String lastWeekKey([DateTime? now]) =>
      weekKey((now ?? DateTime.now()).toUtc().subtract(const Duration(days: 7)));

  CollectionReference<Map<String, dynamic>> _entries(String weekKey) =>
      _db.collection('leaderboards/weekly_$weekKey/entries');

  DocumentReference<Map<String, dynamic>> _claim(String weekKey, String uid) =>
      _db.doc('leaderboards/weekly_$weekKey/claims/$uid');

  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _db.doc('users/$uid/economy/wallet');

  // ── Write my points ─────────────────────────────────────────────────────
  /// Adds [points] to my entry for the current week (idempotency is the
  /// caller's job: this runs once per finished game). Best-effort.
  Future<void> recordPoints({
    required String uid,
    required String name,
    String? photoUrl,
    required int points,
  }) async {
    if (points <= 0) return;
    try {
      await _entries(weekKey()).doc(uid).set({
        'name': name,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'points': FieldValue.increment(points),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('LEADERBOARD',
          'WEEKLY_RECORD_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
    }
  }

  // ── Reads ───────────────────────────────────────────────────────────────
  Stream<List<WeeklyEntry>> topStream({int limit = 20, String? week}) {
    return _entries(week ?? weekKey())
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(WeeklyEntry.fromDoc).toList());
  }

  Future<List<WeeklyEntry>> top({int limit = 3, String? week}) async {
    final snap = await _entries(week ?? weekKey())
        .orderBy('points', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(WeeklyEntry.fromDoc).toList();
  }

  Future<WeeklyEntry?> myEntry(String uid, {String? week}) async {
    final d = await _entries(week ?? weekKey()).doc(uid).get();
    return d.exists ? WeeklyEntry.fromDoc(d) : null;
  }

  /// My 1-based rank this week via an aggregate count of higher scores. Returns
  /// null if I have no entry.
  Future<int?> myRank(String uid, {String? week}) async {
    final me = await myEntry(uid, week: week);
    if (me == null) return null;
    final agg = await _entries(week ?? weekKey())
        .where('points', isGreaterThan: me.points)
        .count()
        .get();
    return (agg.count ?? 0) + 1;
  }

  // ── Last-week podium prize ────────────────────────────────────────────────
  /// Read-only: my unclaimed podium standing for last week, or null. Used to
  /// decide whether to show the claim card.
  Future<({int place, int reward})?> lastWeekPrizeStatus(String uid) async {
    final wk = lastWeekKey();
    final podium = await top(limit: 3, week: wk);
    final place = podium.indexWhere((e) => e.uid == uid);
    if (place < 0) return null;
    final claimed = (await _claim(wk, uid).get()).exists;
    if (claimed) return null;
    return (place: place + 1, reward: podiumRewards[place]);
  }


  /// If I finished in last week's top 3 and haven't claimed, grant the podium
  /// reward once. Returns the coins granted (and my place), or null.
  Future<({int coins, int place})?> claimLastWeekPrize(String uid) async {
    final wk = lastWeekKey();
    // Resolve my place from the ordered top 3 (outside the transaction).
    final podium = await top(limit: 3, week: wk);
    final place = podium.indexWhere((e) => e.uid == uid);
    if (place < 0) return null; // not on the podium
    final reward = podiumRewards[place];

    ({int coins, int place})? result;
    try {
      await _db.runTransaction((tx) async {
        final claimSnap = await tx.get(_claim(wk, uid));
        if (claimSnap.exists) return; // already claimed

        final wSnap = await tx.get(_walletRef(uid));
        final wallet = wSnap.exists
            ? UserEconomyModel.fromFirestore(uid, wSnap.data()!)
            : UserEconomyModel.empty(uid);
        final updated = wallet.copyWith(
          coins: wallet.coins + reward,
          totalEarned: wallet.totalEarned + reward,
        );
        tx.set(_walletRef(uid), updated.toFirestore());
        tx.set(_db.collection('users/$uid/economy_transactions').doc(),
            EconomyTransactionModel(
              id: 'weekly_$wk',
              type: TransactionType.dailyQuest,
              delta: reward,
              balanceAfter: updated.coins,
              createdAt: DateTime.now().toUtc(),
              meta: {'weeklyPodium': place + 1, 'week': wk},
            ).toFirestore());
        tx.set(_claim(wk, uid), {
          'place': place + 1,
          'reward': reward,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        result = (coins: reward, place: place + 1);
      });
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('LEADERBOARD',
          'WEEKLY_PRIZE_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      rethrow;
    }
    return result;
  }
}
