import 'package:cloud_firestore/cloud_firestore.dart';

class UserEconomyModel {
  final String uid;
  final int coins;
  final int totalEarned;
  final int totalSpent;

  // Daily reward tracking (all UTC)
  final DateTime? lastDailyRewardAt;
  final int dailyStreak;

  // Daily spin-wheel tracking (all UTC)
  final DateTime? lastDailySpinAt;

  // Ad reward tracking (all UTC)
  final int adRewardsTodayCount;
  final DateTime? adRewardWindowStart; // start of the UTC day window

  // Free-entry safety net (one free game/day when out of coins, all UTC)
  final DateTime? lastFreeEntryAt;

  // Lifetime stats
  final int totalMatchesPlayed;
  final int totalMatchesWon;
  final int totalHintsUsed;
  // Consecutive wins (resets to 0 on a loss). Drives the "🔥 X streak" banner.
  final int winStreak;

  const UserEconomyModel({
    required this.uid,
    required this.coins,
    required this.totalEarned,
    required this.totalSpent,
    this.lastDailyRewardAt,
    required this.dailyStreak,
    this.lastDailySpinAt,
    required this.adRewardsTodayCount,
    this.adRewardWindowStart,
    this.lastFreeEntryAt,
    required this.totalMatchesPlayed,
    required this.totalMatchesWon,
    required this.totalHintsUsed,
    this.winStreak = 0,
  });

  factory UserEconomyModel.empty(String uid) => UserEconomyModel(
        uid: uid,
        coins: 0,
        totalEarned: 0,
        totalSpent: 0,
        lastDailyRewardAt: null,
        dailyStreak: 0,
        lastDailySpinAt: null,
        adRewardsTodayCount: 0,
        adRewardWindowStart: null,
        lastFreeEntryAt: null,
        totalMatchesPlayed: 0,
        totalMatchesWon: 0,
        totalHintsUsed: 0,
        winStreak: 0,
      );

  factory UserEconomyModel.fromFirestore(String uid, Map<String, dynamic> d) {
    return UserEconomyModel(
      uid: uid,
      coins: (d['coins'] as num? ?? 0).toInt(),
      totalEarned: (d['totalEarned'] as num? ?? 0).toInt(),
      totalSpent: (d['totalSpent'] as num? ?? 0).toInt(),
      lastDailyRewardAt:
          (d['lastDailyRewardAt'] as Timestamp?)?.toDate().toUtc(),
      dailyStreak: (d['dailyStreak'] as num? ?? 0).toInt(),
      lastDailySpinAt:
          (d['lastDailySpinAt'] as Timestamp?)?.toDate().toUtc(),
      adRewardsTodayCount: (d['adRewardsTodayCount'] as num? ?? 0).toInt(),
      adRewardWindowStart:
          (d['adRewardWindowStart'] as Timestamp?)?.toDate().toUtc(),
      lastFreeEntryAt: (d['lastFreeEntryAt'] as Timestamp?)?.toDate().toUtc(),
      totalMatchesPlayed: (d['totalMatchesPlayed'] as num? ?? 0).toInt(),
      totalMatchesWon: (d['totalMatchesWon'] as num? ?? 0).toInt(),
      totalHintsUsed: (d['totalHintsUsed'] as num? ?? 0).toInt(),
      winStreak: (d['winStreak'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'coins': coins,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
        if (lastDailyRewardAt != null)
          'lastDailyRewardAt': Timestamp.fromDate(lastDailyRewardAt!),
        'dailyStreak': dailyStreak,
        if (lastDailySpinAt != null)
          'lastDailySpinAt': Timestamp.fromDate(lastDailySpinAt!),
        'adRewardsTodayCount': adRewardsTodayCount,
        if (adRewardWindowStart != null)
          'adRewardWindowStart': Timestamp.fromDate(adRewardWindowStart!),
        if (lastFreeEntryAt != null)
          'lastFreeEntryAt': Timestamp.fromDate(lastFreeEntryAt!),
        'totalMatchesPlayed': totalMatchesPlayed,
        'totalMatchesWon': totalMatchesWon,
        'totalHintsUsed': totalHintsUsed,
        'winStreak': winStreak,
      };

  UserEconomyModel copyWith({
    int? coins,
    int? totalEarned,
    int? totalSpent,
    DateTime? lastDailyRewardAt,
    int? dailyStreak,
    DateTime? lastDailySpinAt,
    int? adRewardsTodayCount,
    DateTime? adRewardWindowStart,
    DateTime? lastFreeEntryAt,
    int? totalMatchesPlayed,
    int? totalMatchesWon,
    int? totalHintsUsed,
    int? winStreak,
  }) =>
      UserEconomyModel(
        uid: uid,
        coins: coins ?? this.coins,
        totalEarned: totalEarned ?? this.totalEarned,
        totalSpent: totalSpent ?? this.totalSpent,
        lastDailyRewardAt: lastDailyRewardAt ?? this.lastDailyRewardAt,
        dailyStreak: dailyStreak ?? this.dailyStreak,
        lastDailySpinAt: lastDailySpinAt ?? this.lastDailySpinAt,
        adRewardsTodayCount: adRewardsTodayCount ?? this.adRewardsTodayCount,
        adRewardWindowStart: adRewardWindowStart ?? this.adRewardWindowStart,
        lastFreeEntryAt: lastFreeEntryAt ?? this.lastFreeEntryAt,
        totalMatchesPlayed: totalMatchesPlayed ?? this.totalMatchesPlayed,
        totalMatchesWon: totalMatchesWon ?? this.totalMatchesWon,
        totalHintsUsed: totalHintsUsed ?? this.totalHintsUsed,
        winStreak: winStreak ?? this.winStreak,
      );
}
