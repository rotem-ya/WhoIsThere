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
              color: const Color(0xFF87CEEB)
                  .withOpacity(canAfford ? 0.38 : 0.18),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFF87CEEB), size: 18),
              const SizedBox(width: 6),
              Text(
                'רמז  (${EconomyConfig.hintRevealTilePrice} 🪙)',
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFF87CEEB),
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
                          fontSize: 20,
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
