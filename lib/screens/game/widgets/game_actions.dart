import 'package:flutter/material.dart';

import '../../../widgets/game/animated_reward.dart';

class GameActions extends StatelessWidget {
  final bool isMyTurn;
  final bool isBusy;
  final bool canGuessNow;
  final int revealedCount;
  final int totalTiles;
  final VoidCallback? onGuess;
  final VoidCallback? onSkip;

  const GameActions({
    required this.isMyTurn,
    required this.isBusy,
    required this.canGuessNow,
    required this.revealedCount,
    required this.totalTiles,
    required this.onGuess,
    required this.onSkip,
  });

  int _reward() => _calcReward(revealedCount, totalTiles);

  int _penalty(int reward) => (reward * 0.15).round();

  @override
  Widget build(BuildContext context) {
    final reward = _reward();
    final penalty = _penalty(reward);
    final guessActive = canGuessNow && !isBusy;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: _ActionButton(
                  label: canGuessNow
                      ? 'נחש'
                      : isMyTurn
                          ? 'בחר משבצת'
                          : 'ממתין לתור',
                  isPrimary: true,
                  isActive: guessActive || (isMyTurn && !canGuessNow),
                  glow: guessActive,
                  onTap: guessActive ? onGuess : null,
                  reward: canGuessNow ? reward : null,
                  penalty: canGuessNow ? penalty : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: _ActionButton(
                  label: 'דלג',
                  isPrimary: false,
                  isActive: canGuessNow && !isBusy,
                  glow: false,
                  onTap: canGuessNow && !isBusy ? onSkip : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final bool isActive;
  final bool glow;
  final VoidCallback? onTap;
  final int? reward;
  final int? penalty;

  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.isActive,
    required this.glow,
    required this.onTap,
    this.reward,
    this.penalty,
  });

  @override
  Widget build(BuildContext context) {
    final hasReward = reward != null && penalty != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isActive ? 1.0 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 50,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF9B7EFF), Color(0xFF6B44F8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary ? null : Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(18),
            border: isPrimary
                ? null
                : Border.all(
                    color: Colors.white.withOpacity(isActive ? 0.28 : 0.12),
                    width: 1,
                  ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: const Color(0xFF7B5FFF).withOpacity(0.46),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isPrimary && label == 'נחש' && hasReward
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'נחש',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedReward(
                              key: ValueKey('penalty_$penalty'),
                              value: penalty!,
                              isPositive: false,
                            ),
                            const SizedBox(width: 12),
                            AnimatedReward(
                              key: ValueKey('reward_$reward'),
                              value: reward!,
                              isPositive: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      style: TextStyle(
                        color: isPrimary ? Colors.white : Colors.white70,
                        fontSize: isPrimary ? 21 : 18,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

