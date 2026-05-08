class EconomyConfig {
  EconomyConfig._();

  // Starting balance for new users
  static const int initialCoins = 100;

  // ── Hint prices ──────────────────────────────────────────────
  static const int hintRevealTilePrice = 20;
  static const int hintExtraGuessPrice = 30;

  // ── Match rewards: solo ───────────────────────────────────────
  static const int soloWinBase = 40;
  static const int soloParticipation = 10; // every play (not win)

  // ── Match rewards: multiplayer ────────────────────────────────
  static const int multiWinBase = 60;
  static const int multiParticipation = 15;

  // ── Speed bonuses (seconds from game-start to correct guess) ──
  static const int speedBonusFast = 20;      // ≤ 30 s
  static const int speedBonusMedium = 10;    // ≤ 60 s
  static const int speedThresholdFastSec = 30;
  static const int speedThresholdMediumSec = 60;

  // ── Efficiency bonus (tiles revealed when guessing correctly) ─
  // fewer revealed tiles → bigger bonus
  static const int efficiencyBonusTier1 = 25; // 1–2 tiles revealed
  static const int efficiencyBonusTier2 = 15; // 3–4 tiles revealed
  static const int efficiencyBonusTier3 = 5;  // 5–6 tiles revealed
  static const int efficiencyTier1MaxTiles = 2;
  static const int efficiencyTier2MaxTiles = 4;
  static const int efficiencyTier3MaxTiles = 6;

  // ── Daily login reward ────────────────────────────────────────
  static const int dailyRewardBase = 25;
  // Consecutive day streak multipliers (index = streak day, capped at 7)
  static const List<int> streakBonusCoins = [0, 0, 5, 10, 15, 25, 40, 60];

  // ── Ad-watch reward ───────────────────────────────────────────
  static const int adRewardCoins = 50;
  static const int maxAdRewardsPerDay = 3;

  // ── Coin pack prices (store SKUs) ────────────────────────────
  static const Map<String, int> coinPacks = {
    'coins_small': 100,
    'coins_medium': 300,
    'coins_large': 750,
  };
}
