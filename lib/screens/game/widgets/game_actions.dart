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
  final bool isBlocked;
  final int blockedRemaining;

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
    this.isScoreCliff = false,
    this.isBlocked = false,
    this.blockedRemaining = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prize = RewardCalculator.calculateCurrentPrizePotential(
      isSolo: isSolo,
      revealedCount: revealedCount,
      totalTiles: totalTiles,
    );
    final guessActive = canGuessNow && !isBusy;
    // Button is active whenever not blocked and not in an opponent's guessMode
    final buttonActive = !isBlocked && !isGuessModeActive && !isBusy;

    // Hint affordability — solo only; guard already enforces this server-side
    final wallet = isSolo ? ref.watch(walletProvider).valueOrNull : null;
    final guard = isSolo ? ref.watch(hintEconomyGuardProvider) : null;
    final canAffordHint = wallet != null &&
        guard != null &&
        guard.canAfford(wallet, HintType.revealTile);

    // Primary button label driven by state machine phase
    final String primaryLabel;
    if (isBlocked) {
      primaryLabel = blockedRemaining > 0 ? 'חסום ($blockedRemaining גילויים)' : 'חסום';
    } else if (isGuessModeActive) {
      final name = guessModePlayerName.isEmpty ? 'יריב' : guessModePlayerName;
      primaryLabel = '$name מנחש!';
    } else if (canGuessNow) {
      primaryLabel = 'נחש עכשיו!';
    } else {
      primaryLabel = 'נחש!';
    }

    final primaryIsActive = buttonActive;
    final primaryGlow = guessActive;
    final primaryOnTap = buttonActive ? onGuess : null;

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
              _ActionButton(
                label: primaryLabel,
                isPrimary: true,
                isActive: primaryIsActive,
                glow: primaryGlow,
                onTap: primaryOnTap,
                reward: showReward ? prize : null,
              ),
              // Hint button — only in solo mode (shown regardless of turn state)
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
                      Color(0xFF20A8E0),
                      Color(0xFF0E88C8),
                      Color(0xFF0868A8),
                      Color(0xFF054880),
                    ],
                    stops: [0.0, 0.38, 0.72, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: isPrimary ? null : const Color(0xFF081828).withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.35)
                  : const Color(0xFF2080C0).withOpacity(isActive ? 0.45 : 0.20),
              width: 1.0,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: const Color(0xFF10A0E0).withOpacity(0.60),
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0050B0).withOpacity(0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : isPrimary
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0050B0).withOpacity(0.45),
                          blurRadius: 10,
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
                  height: 16,
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
                          Colors.white.withOpacity(0.24),
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
                              color: Colors.white,
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
                                ? Colors.white
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
