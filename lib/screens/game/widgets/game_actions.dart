import 'package:flutter/material.dart';

import '../../../services/feedback_service.dart';
import '../../../widgets/game/animated_reward.dart';

int _calcReward(int revealedCount, int total) {
  if (total == 0) return 100;
  return (100 - revealedCount / total * 80).clamp(20.0, 100.0).round();
}

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
      onTap: onTap == null
          ? null
          : () {
              FeedbackService.click();
              onTap!();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isActive ? 1.0 : 0.42,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 54,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isPrimary ? null : const Color(0xFF07101F).withOpacity(0.64),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.16)
                  : const Color(0xFF87CEEB).withOpacity(isActive ? 0.40 : 0.16),
              width: 1.2,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : isPrimary
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
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
                          color: Color(0xFF07101F),
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
                        color: isPrimary ? const Color(0xFF07101F) : Colors.white.withOpacity(0.78),
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
