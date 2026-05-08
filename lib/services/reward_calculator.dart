import '../core/constants/economy_config.dart';
import '../models/economy/match_reward_breakdown.dart';

/// Pure Dart logic — no Firebase, no Flutter, no side effects.
class RewardCalculator {
  const RewardCalculator._();

  // ── Match reward ──────────────────────────────────────────────

  static MatchRewardBreakdown calculateMatchReward({
    required bool isWin,
    required bool isSolo,
    required int tilesRevealedCount,
    required Duration timeTaken,
  }) {
    final base = isWin
        ? (isSolo ? EconomyConfig.soloWinBase : EconomyConfig.multiWinBase)
        : (isSolo
            ? EconomyConfig.soloParticipation
            : EconomyConfig.multiParticipation);

    final speed = isWin ? _speedBonus(timeTaken.inSeconds) : 0;
    final efficiency = isWin ? _efficiencyBonus(tilesRevealedCount) : 0;

    return MatchRewardBreakdown(
      baseReward: base,
      speedBonus: speed,
      efficiencyBonus: efficiency,
      isWin: isWin,
      isSolo: isSolo,
    );
  }

  // ── Daily reward ──────────────────────────────────────────────

  /// Returns the total coins to award for a daily login.
  static int calculateDailyReward(int currentStreak) {
    final clampedStreak = currentStreak.clamp(0, EconomyConfig.streakBonusCoins.length - 1);
    return EconomyConfig.dailyRewardBase + EconomyConfig.streakBonusCoins[clampedStreak];
  }

  /// Returns the new streak value given whether today is a consecutive day.
  /// [lastRewardAt] must be UTC; [now] must be UTC.
  static int computeNewStreak(int currentStreak, DateTime? lastRewardAt, DateTime now) {
    if (lastRewardAt == null) return 1;

    final lastDate = DateTime.utc(lastRewardAt.year, lastRewardAt.month, lastRewardAt.day);
    final todayDate = DateTime.utc(now.year, now.month, now.day);
    final diff = todayDate.difference(lastDate).inDays;

    if (diff == 1) return currentStreak + 1; // consecutive
    if (diff == 0) return currentStreak;     // same day — no change
    return 1;                                // streak broken
  }

  // ── Private helpers ───────────────────────────────────────────

  static int _speedBonus(int seconds) {
    if (seconds <= EconomyConfig.speedThresholdFastSec) {
      return EconomyConfig.speedBonusFast;
    } else if (seconds <= EconomyConfig.speedThresholdMediumSec) {
      return EconomyConfig.speedBonusMedium;
    }
    return 0;
  }

  static int _efficiencyBonus(int tilesRevealed) {
    if (tilesRevealed <= EconomyConfig.efficiencyTier1MaxTiles) {
      return EconomyConfig.efficiencyBonusTier1;
    } else if (tilesRevealed <= EconomyConfig.efficiencyTier2MaxTiles) {
      return EconomyConfig.efficiencyBonusTier2;
    } else if (tilesRevealed <= EconomyConfig.efficiencyTier3MaxTiles) {
      return EconomyConfig.efficiencyBonusTier3;
    }
    return 0;
  }
}
