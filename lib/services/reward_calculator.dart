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
    required int totalTilesCount,
    required int wrongGuessCount,
    required Duration timeTaken,
  }) {
    final double revealRatio = totalTilesCount <= 0
        ? 1.0
        : (tilesRevealedCount / totalTilesCount).clamp(0.0, 1.0);

    if (!isWin) {
      return MatchRewardBreakdown(
        baseReward: isSolo
            ? EconomyConfig.soloParticipation
            : EconomyConfig.multiParticipation,
        earlyGuessBonus: 0,
        speedBonus: 0,
        noWrongGuessBonus: 0,
        perfectRoundBonus: 0,
        wrongGuessPenalty: 0,
        isWin: false,
        isSolo: isSolo,
        tilesRevealedCount: tilesRevealedCount,
        totalTilesCount: totalTilesCount,
        revealRatio: revealRatio,
        wrongGuessCount: wrongGuessCount,
      );
    }

    final base = isSolo ? EconomyConfig.soloWinBase : EconomyConfig.multiWinBase;
    final earlyGuess = _earlyGuessBonus(revealRatio);
    final speed = _speedBonus(timeTaken.inSeconds);
    final noWrong = wrongGuessCount == 0 ? EconomyConfig.noWrongGuessBonus : 0;
    final perfect = (wrongGuessCount == 0 &&
            revealRatio <= EconomyConfig.perfectRevealRatioMax)
        ? EconomyConfig.perfectRoundBonus
        : 0;
    final penalty =
        (wrongGuessCount * EconomyConfig.wrongGuessPenaltyPerGuess)
            .clamp(0, EconomyConfig.maxWrongGuessPenalty);

    return MatchRewardBreakdown(
      baseReward: base,
      earlyGuessBonus: earlyGuess,
      speedBonus: speed,
      noWrongGuessBonus: noWrong,
      perfectRoundBonus: perfect,
      wrongGuessPenalty: penalty,
      isWin: true,
      isSolo: isSolo,
      tilesRevealedCount: tilesRevealedCount,
      totalTilesCount: totalTilesCount,
      revealRatio: revealRatio,
      wrongGuessCount: wrongGuessCount,
    );
  }

  // ── Prize potential (HUD preview, no speed / no penalty) ─────

  /// Approximate coins the player would earn guessing correctly right now,
  /// assuming zero wrong guesses. Speed bonus is excluded because the HUD
  /// should not fluctuate by time.
  static int calculateCurrentPrizePotential({
    required bool isSolo,
    required int revealedCount,
    required int totalTiles,
  }) {
    final base = isSolo ? EconomyConfig.soloWinBase : EconomyConfig.multiWinBase;
    final ratio = totalTiles <= 0
        ? 1.0
        : (revealedCount / totalTiles).clamp(0.0, 1.0);
    final earlyGuess = _earlyGuessBonus(ratio);
    final perfect = ratio <= EconomyConfig.perfectRevealRatioMax
        ? EconomyConfig.perfectRoundBonus
        : 0;
    return base + earlyGuess + EconomyConfig.noWrongGuessBonus + perfect;
  }

  // ── Daily reward ──────────────────────────────────────────────

  /// Returns the total coins to award for a daily login.
  static int calculateDailyReward(int currentStreak) {
    final clampedStreak =
        currentStreak.clamp(0, EconomyConfig.streakBonusCoins.length - 1);
    return EconomyConfig.dailyRewardBase +
        EconomyConfig.streakBonusCoins[clampedStreak];
  }

  /// Returns the new streak value given whether today is a consecutive day.
  /// [lastRewardAt] must be UTC; [now] must be UTC.
  static int computeNewStreak(
      int currentStreak, DateTime? lastRewardAt, DateTime now) {
    if (lastRewardAt == null) return 1;

    final lastDate =
        DateTime.utc(lastRewardAt.year, lastRewardAt.month, lastRewardAt.day);
    final todayDate = DateTime.utc(now.year, now.month, now.day);
    final diff = todayDate.difference(lastDate).inDays;

    if (diff == 1) return currentStreak + 1; // consecutive
    if (diff == 0) return currentStreak; // same day — no change
    return 1; // streak broken
  }

  // ── Private helpers ───────────────────────────────────────────

  static int _earlyGuessBonus(double ratio) {
    if (ratio <= EconomyConfig.earlyGuessTier1MaxRatio) {
      return EconomyConfig.earlyGuessBonusTier1;
    }
    if (ratio <= EconomyConfig.earlyGuessTier2MaxRatio) {
      return EconomyConfig.earlyGuessBonusTier2;
    }
    if (ratio <= EconomyConfig.earlyGuessTier3MaxRatio) {
      return EconomyConfig.earlyGuessBonusTier3;
    }
    if (ratio <= EconomyConfig.earlyGuessTier4MaxRatio) {
      return EconomyConfig.earlyGuessBonusTier4;
    }
    return EconomyConfig.earlyGuessBonusTier5;
  }

  static int _speedBonus(int seconds) {
    if (seconds <= EconomyConfig.speedThresholdFastSec) {
      return EconomyConfig.speedBonusFast;
    } else if (seconds <= EconomyConfig.speedThresholdMediumSec) {
      return EconomyConfig.speedBonusMedium;
    }
    return 0;
  }
}
