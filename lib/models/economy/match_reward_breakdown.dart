/// Immutable summary of coins earned at the end of a single match.
class MatchRewardBreakdown {
  final int baseReward;
  final int earlyGuessBonus;
  final int speedBonus;
  final int noWrongGuessBonus;
  final int perfectRoundBonus;
  final int wrongGuessPenalty;
  final bool isWin;
  final bool isSolo;
  final int tilesRevealedCount;
  final int totalTilesCount;
  final double revealRatio;
  final int wrongGuessCount;

  const MatchRewardBreakdown({
    required this.baseReward,
    required this.earlyGuessBonus,
    required this.speedBonus,
    required this.noWrongGuessBonus,
    required this.perfectRoundBonus,
    required this.wrongGuessPenalty,
    required this.isWin,
    required this.isSolo,
    required this.tilesRevealedCount,
    required this.totalTilesCount,
    required this.revealRatio,
    required this.wrongGuessCount,
  });

  // Backward-compat getter — game_winner_view.dart references efficiencyBonus.
  int get efficiencyBonus => earlyGuessBonus;

  int get total => (baseReward + earlyGuessBonus + speedBonus +
          noWrongGuessBonus + perfectRoundBonus - wrongGuessPenalty)
      .clamp(0, 99999);

  static const zero = MatchRewardBreakdown(
    baseReward: 0,
    earlyGuessBonus: 0,
    speedBonus: 0,
    noWrongGuessBonus: 0,
    perfectRoundBonus: 0,
    wrongGuessPenalty: 0,
    isWin: false,
    isSolo: false,
    tilesRevealedCount: 0,
    totalTilesCount: 1,
    revealRatio: 0.0,
    wrongGuessCount: 0,
  );
}
