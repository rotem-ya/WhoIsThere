/// Immutable summary of coins earned at the end of a single match.
class MatchRewardBreakdown {
  final int baseReward;
  final int speedBonus;
  final int efficiencyBonus;
  final bool isWin;
  final bool isSolo;

  const MatchRewardBreakdown({
    required this.baseReward,
    required this.speedBonus,
    required this.efficiencyBonus,
    required this.isWin,
    required this.isSolo,
  });

  int get total => baseReward + speedBonus + efficiencyBonus;

  static const zero = MatchRewardBreakdown(
    baseReward: 0,
    speedBonus: 0,
    efficiencyBonus: 0,
    isWin: false,
    isSolo: false,
  );
}
