class EconomyConfig {
  EconomyConfig._();

  // Starting balance for new users (granted on first install)
  static const int initialCoins = 100;

  // ── Game entry & pot ─────────────────────────────────────────
  static const int gameEntryFee = 20;

  // ── Guess-claim cost (pressing the guess button) ─────────────
  // 1st press = 2, 2nd = 4, 3rd = 6 … all goes to the pot
  static const int baseGuessClaimCost = 2;
  static const int guessClaimCostIncrement = 2;

  // ── Wrong-guess penalty (each wrong answer, added to pot) ────
  // 1st wrong = 2, 2nd = 4, 3rd = 6 …
  static const int baseWrongGuessPenalty = 2;
  static const int wrongGuessPenaltyIncrement = 2;

  // ── Block duration on wrong guess (in reveal-count units) ────
  static const int wrongGuessBlockTurns = 2;

  // ── Hint prices ──────────────────────────────────────────────
  static const int hintFirstPrice = 40;       // first hint purchase
  static const int hintSecondPrice = 80;      // second hint purchase
  static const int hintRevealTilePrice = 40;  // legacy alias (= hintFirstPrice)
  static const int hintExtraGuessPrice = 60;

  // ── Match rewards: solo ───────────────────────────────────────
  static const int soloWinBase = 10;
  static const int soloParticipation = 2;

  // ── Match rewards: multiplayer (bonus on top of pot win) ──────
  static const int multiWinBase = 5;
  static const int multiParticipation = 0;

  // ── Speed bonuses (seconds from game-start to correct guess) ──
  static const int speedBonusFast = 5;        // ≤ 30 s
  static const int speedBonusMedium = 3;      // ≤ 60 s
  static const int speedThresholdFastSec = 30;
  static const int speedThresholdMediumSec = 60;

  // ── Early-guess bonus (reveal ratio when guessing correctly) ──
  static const double earlyGuessTier1MaxRatio = 0.20;
  static const double earlyGuessTier2MaxRatio = 0.35;
  static const double earlyGuessTier3MaxRatio = 0.50;
  static const double earlyGuessTier4MaxRatio = 0.70;
  static const int earlyGuessBonusTier1 = 15; // ≤ 20% revealed
  static const int earlyGuessBonusTier2 = 10; // ≤ 35% revealed
  static const int earlyGuessBonusTier3 = 7;  // ≤ 50% revealed
  static const int earlyGuessBonusTier4 = 3;  // ≤ 70% revealed
  static const int earlyGuessBonusTier5 = 0;  // > 70% revealed

  // ── No-wrong-guess & perfect-round bonuses ─────────────────────
  static const int noWrongGuessBonus = 5;
  static const double perfectRevealRatioMax = 0.30;
  static const int perfectRoundBonus = 5;

  // ── Wrong-guess penalty ────────────────────────────────────────
  static const int wrongGuessPenaltyPerGuess = 10;
  static const int maxWrongGuessPenalty = 25;

  // ── Guess-timeout penalty (guessMode expired without answering) ─
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
  static const int dailyRewardBase = 20;
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

  // ── Auto-reveal race mechanic ─────────────────────────────────
  static const int autoRevealIntervalMs = 4000;

  // ── Entry fee options (for future host selection UI) ─────────
  static const List<int> entryFeeOptions = [0, 10, 25, 50];
}
