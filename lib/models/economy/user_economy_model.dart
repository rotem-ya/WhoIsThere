import 'package:cloud_firestore/cloud_firestore.dart';

class UserEconomyModel {
  final String uid;
  final int coins;
  final int totalEarned;
  final int totalSpent;

  // Daily reward tracking (all UTC)
  final DateTime? lastDailyRewardAt;
  final int dailyStreak;

  // Ad reward tracking (all UTC)
  final int adRewardsTodayCount;
  final DateTime? adRewardWindowStart; // start of the UTC day window

  // Lifetime stats
  final int totalMatchesPlayed;
  final int totalMatchesWon;
  final int totalHintsUsed;

  const UserEconomyModel({
    required this.uid,
    required this.coins,
    required this.totalEarned,
    required this.totalSpent,
    this.lastDailyRewardAt,
    required this.dailyStreak,
    required this.adRewardsTodayCount,
    this.adRewardWindowStart,
    required this.totalMatchesPlayed,
    required this.totalMatchesWon,
    required this.totalHintsUsed,
  });

  factory UserEconomyModel.empty(String uid) => UserEconomyModel(
        uid: uid,
        coins: 0,
        totalEarned: 0,
        totalSpent: 0,
        lastDailyRewardAt: null,
        dailyStreak: 0,
        adRewardsTodayCount: 0,
        adRewardWindowStart: null,
        totalMatchesPlayed: 0,
        totalMatchesWon: 0,
        totalHintsUsed: 0,
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
      adRewardsTodayCount: (d['adRewardsTodayCount'] as num? ?? 0).toInt(),
      adRewardWindowStart:
          (d['adRewardWindowStart'] as Timestamp?)?.toDate().toUtc(),
      totalMatchesPlayed: (d['totalMatchesPlayed'] as num? ?? 0).toInt(),
      totalMatchesWon: (d['totalMatchesWon'] as num? ?? 0).toInt(),
      totalHintsUsed: (d['totalHintsUsed'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'coins': coins,
        'totalEarned': totalEarned,
        'totalSpent': totalSpent,
        if (lastDailyRewardAt != null)
          'lastDailyRewardAt': Timestamp.fromDate(lastDailyRewardAt!),
        'dailyStreak': dailyStreak,
        'adRewardsTodayCount': adRewardsTodayCount,
        if (adRewardWindowStart != null)
          'adRewardWindowStart': Timestamp.fromDate(adRewardWindowStart!),
        'totalMatchesPlayed': totalMatchesPlayed,
        'totalMatchesWon': totalMatchesWon,
        'totalHintsUsed': totalHintsUsed,
      };

  UserEconomyModel copyWith({
    int? coins,
    int? totalEarned,
    int? totalSpent,
    DateTime? lastDailyRewardAt,
    int? dailyStreak,
    int? adRewardsTodayCount,
    DateTime? adRewardWindowStart,
    int? totalMatchesPlayed,
    int? totalMatchesWon,
    int? totalHintsUsed,
  }) =>
      UserEconomyModel(
        uid: uid,
        coins: coins ?? this.coins,
        totalEarned: totalEarned ?? this.totalEarned,
        totalSpent: totalSpent ?? this.totalSpent,
        lastDailyRewardAt: lastDailyRewardAt ?? this.lastDailyRewardAt,
        dailyStreak: dailyStreak ?? this.dailyStreak,
        adRewardsTodayCount: adRewardsTodayCount ?? this.adRewardsTodayCount,
        adRewardWindowStart: adRewardWindowStart ?? this.adRewardWindowStart,
        totalMatchesPlayed: totalMatchesPlayed ?? this.totalMatchesPlayed,
        totalMatchesWon: totalMatchesWon ?? this.totalMatchesWon,
        totalHintsUsed: totalHintsUsed ?? this.totalHintsUsed,
      );
}
