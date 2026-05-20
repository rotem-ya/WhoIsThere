class EconomyConfig {
  EconomyConfig._();

  // Starting balance for new users
  static const int initialCoins = 100;

  // ── Hint prices ──────────────────────────────────────────────
  static const int hintRevealTilePrice = 40;
  static const int hintExtraGuessPrice = 60;

  // ── Match rewards: solo ───────────────────────────────────────
  static const int soloWinBase = 15;
  static const int soloParticipation = 2;

  // ── Match rewards: multiplayer ────────────────────────────────
  static const int multiWinBase = 20;
  static const int multiParticipation = 0;

  // ── Speed bonuses (seconds from game-start to correct guess) ──
  static const int speedBonusFast = 8;        // ≤ 30 s
  static const int speedBonusMedium = 4;      // ≤ 60 s
  static const int speedThresholdFastSec = 30;
  static const int speedThresholdMediumSec = 60;

  // ── Early-guess bonus (reveal ratio when guessing correctly) ──
  // Lower reveal ratio → bigger bonus; rewards early correct recognition.
  static const double earlyGuessTier1MaxRatio = 0.20;
  static const double earlyGuessTier2MaxRatio = 0.35;
  static const double earlyGuessTier3MaxRatio = 0.50;
  static const double earlyGuessTier4MaxRatio = 0.70;
  static const int earlyGuessBonusTier1 = 45; // ≤ 20% revealed
  static const int earlyGuessBonusTier2 = 30; // ≤ 35% revealed
  static const int earlyGuessBonusTier3 = 15; // ≤ 50% revealed
  static const int earlyGuessBonusTier4 = 5;  // ≤ 70% revealed
  static const int earlyGuessBonusTier5 = 0;  // > 70% revealed

  // ── No-wrong-guess & perfect-round bonuses ─────────────────────
  static const int noWrongGuessBonus = 8;
  static const double perfectRevealRatioMax = 0.30;
  static const int perfectRoundBonus = 12;

  // ── Wrong-guess penalty ────────────────────────────────────────
  static const int wrongGuessPenaltyPerGuess = 10;
  static const int maxWrongGuessPenalty = 25;

  // ── Live in-game guess penalties (guessMode phase) ─────────────
  static const int wrongGuessLivePenalty = 3;
  static const int guessTimeoutLivePenalty = 3;

  // ── Efficiency bonus (deprecated — kept for schema compat) ────
  // @deprecated Use earlyGuessBonus ratio-based constants instead.
  static const int efficiencyBonusTier1 = 25;
  static const int efficiencyBonusTier2 = 15;
  static const int efficiencyBonusTier3 = 5;
  static const int efficiencyTier1MaxTiles = 2;
  static const int efficiencyTier2MaxTiles = 4;
  static const int efficiencyTier3MaxTiles = 6;

  // ── Daily login reward ────────────────────────────────────────
  static const int dailyRewardBase = 5;
  // Consecutive day streak multipliers (index = streak day, capped at 7)
  static const List<int> streakBonusCoins = [0, 0, 2, 3, 5, 7, 10, 12];

  // ── Ad-watch reward ───────────────────────────────────────────
  static const int adRewardCoins = 10;
  static const int maxAdRewardsPerDay = 2;

  // ── Coin pack prices (store SKUs) ────────────────────────────
  static const Map<String, int> coinPacks = {
    'coins_small': 100,
    'coins_medium': 300,
    'coins_large': 750,
  };
}
