import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/economy_config.dart';
import '../../../providers/providers.dart';
import '../../../services/feedback_service.dart';
import '../../../services/hint_economy_guard.dart';
import '../../../services/reward_calculator.dart';
import '../../../widgets/game/animated_reward.dart';

class GameActions extends ConsumerWidget {
  final bool isMyTurn;
  final bool isBusy;
  final bool canGuessNow;
  final bool isSolo;
  final int revealedCount;
  final int totalTiles;
  final bool isGuessModeActive;
  final bool isScoreCliff;
  final String guessModePlayerName;
  final VoidCallback? onRevealHint;
  final VoidCallback? onGuess;
  final VoidCallback? onSkip;

  const GameActions({
    required this.isMyTurn,
    required this.isBusy,
    required this.canGuessNow,
    required this.isSolo,
    required this.revealedCount,
    required this.totalTiles,
    required this.isGuessModeActive,
    required this.guessModePlayerName,
    required this.onRevealHint,
    required this.onGuess,
    required this.onSkip,
    this.isScoreCliff = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prize = RewardCalculator.calculateCurrentPrizePotential(
      isSolo: isSolo,
      revealedCount: revealedCount,
      totalTiles: totalTiles,
    );
    final guessActive = canGuessNow && !isBusy;

    // Hint affordability — solo only; guard already enforces this server-side
    final wallet = isSolo ? ref.watch(walletProvider).valueOrNull : null;
    final guard = isSolo ? ref.watch(hintEconomyGuardProvider) : null;
    final canAffordHint = wallet != null &&
        guard != null &&
        guard.canAfford(wallet, HintType.revealTile);

    // Primary button label driven by state machine phase
    final String primaryLabel;
    if (canGuessNow) {
      primaryLabel = 'נחש עכשיו!';
    } else if (isGuessModeActive) {
      final name = guessModePlayerName.isEmpty ? 'יריב' : guessModePlayerName;
      primaryLabel = '$name מנחש!';
    } else if (isMyTurn) {
      primaryLabel = 'בחר משבצת';
    } else {
      primaryLabel = 'ממתין לתור';
    }

    final primaryIsActive =
        guessActive || (isMyTurn && !canGuessNow && !isGuessModeActive);
    final primaryGlow = guessActive;
    final primaryOnTap = guessActive ? onGuess : null;

    // Show reward chip on the guess opportunity CTA only
    final showReward = canGuessNow && prize != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isScoreCliff && canGuessNow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'פרס הניצחון מחכה!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFE082),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: _ActionButton(
                      label: primaryLabel,
                      isPrimary: true,
                      isActive: primaryIsActive,
                      glow: primaryGlow,
                      onTap: primaryOnTap,
                      reward: showReward ? prize : null,
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
              // Hint button — only in solo mode
              if (isSolo && onRevealHint != null) ...[
                const SizedBox(height: 6),
                _HintButton(
                  canAfford: canAffordHint,
                  isBusy: isBusy,
                  onTap: canAffordHint && !isBusy ? onRevealHint : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  final bool canAfford;
  final bool isBusy;
  final VoidCallback? onTap;

  const _HintButton({
    required this.canAfford,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              FeedbackService.click();
              onTap!();
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: canAfford && !isBusy ? 1.0 : 0.42,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.56),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF4A8BAA)
                  .withOpacity(canAfford ? 0.32 : 0.14),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFF5A9BBB), size: 18),
              const SizedBox(width: 6),
              Text(
                'רמז  (${EconomyConfig.hintRevealTilePrice} 🪙)',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFF5A9BBB),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
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

  const _ActionButton({
    required this.label,
    required this.isPrimary,
    required this.isActive,
    required this.glow,
    required this.onTap,
    this.reward,
  });

  @override
  Widget build(BuildContext context) {
    final hasReward = reward != null;

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
          height: 48,
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [
                      Color(0xFFEDCE78),
                      Color(0xFFC49530),
                      Color(0xFF9A7220),
                      Color(0xFF7D5C14),
                    ],
                    stops: [0.0, 0.38, 0.72, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isPrimary ? null : const Color(0xFF07101F).withOpacity(0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.22)
                  : Colors.white.withOpacity(isActive ? 0.14 : 0.08),
              width: 1.0,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: const Color(0xFFBF9030).withOpacity(0.38),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : isPrimary
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
          ),
          child: Stack(
            children: [
              if (isPrimary)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.13),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Center(
                child: isPrimary && hasReward
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Color(0xFF07101F),
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedReward(
                              key: ValueKey('reward_$reward'),
                              value: reward!,
                              isPositive: true,
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
                            color: isPrimary
                                ? const Color(0xFF0A1828)
                                : Colors.white.withOpacity(0.75),
                            fontSize: isPrimary ? 20 : 17,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
