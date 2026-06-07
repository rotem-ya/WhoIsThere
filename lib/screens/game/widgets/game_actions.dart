import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/economy_config.dart';
import '../../../core/constants/game_constants.dart';
import '../../../models/player_model.dart';
import '../../../providers/providers.dart';
import '../../../services/feedback_service.dart';
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
  final int purchasedHintCount;
  final VoidCallback? onBuySecondHint;
  final VoidCallback? onGuess;
  final bool isBlocked;
  final int blockedRemaining;
  final bool isTimeBlocked;
  final int timeBlockSecsLeft;
  final int stunCardCount;
  final bool canUseStunCard;
  final List<PlayerModel> stunTargets;
  final Future<void> Function(String targetId)? onStunCard;

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
    this.purchasedHintCount = 0,
    this.onBuySecondHint,
    this.isScoreCliff = false,
    this.isBlocked = false,
    this.blockedRemaining = 0,
    this.isTimeBlocked = false,
    this.timeBlockSecsLeft = 0,
    this.stunCardCount = 0,
    this.canUseStunCard = false,
    this.stunTargets = const [],
    this.onStunCard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earlyBonus = RewardCalculator.calculateEarlyGuessBonus(
      revealedCount: revealedCount,
      totalTiles: totalTiles,
    );
    final guessActive = canGuessNow && !isBusy;

    // Hint affordability — solo only; guard already enforces this server-side
    final wallet = isSolo ? ref.watch(walletProvider).valueOrNull : null;
    final canAffordFirstHint = wallet != null && wallet.coins >= EconomyConfig.hintFirstPrice;
    final canAffordSecondHint = wallet != null && wallet.coins >= EconomyConfig.hintSecondPrice;

    // Primary button label
    final _anyBlocked = isBlocked || isTimeBlocked;
    final String primaryLabel;
    if (isTimeBlocked && timeBlockSecsLeft > 0) {
      primaryLabel = 'חסום (${timeBlockSecsLeft}s)';
    } else if (isBlocked) {
      primaryLabel = blockedRemaining > 0 ? 'חסום ($blockedRemaining גילויים)' : 'חסום';
    } else {
      primaryLabel = 'נחש עכשיו!';
    }

    // Always active (button is always tappable; shows toast if wrong phase)
    final primaryIsActive = !_anyBlocked;
    final primaryGlow = guessActive && !_anyBlocked;
    final primaryOnTap = _anyBlocked ? null : onGuess;

    // Show the decaying early-guess bonus always (hides itself when it hits 0)
    final showReward = earlyBonus > 0;

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
                reward: showReward ? earlyBonus : null,
              ),
              // Hint button — only in solo mode (shown regardless of turn state).
              // Gated behind GameConstants.hintsEnabled and only surfaces once
              // 70% of the board is revealed, so it acts as a late rescue.
              if (GameConstants.hintsEnabled &&
                  isSolo &&
                  onRevealHint != null &&
                  totalTiles > 0 &&
                  revealedCount >= totalTiles * GameConstants.hintRevealThreshold) ...[
                const SizedBox(height: 6),
                _HintButton(
                  label: purchasedHintCount >= 1
                      ? 'ראה רמז'
                      : 'רמז  (${EconomyConfig.hintFirstPrice} 🪙)',
                  canAfford: purchasedHintCount >= 1 || (canAffordFirstHint && !isBusy),
                  isBusy: isBusy && purchasedHintCount == 0,
                  onTap: (purchasedHintCount >= 1 || (canAffordFirstHint && !isBusy))
                      ? onRevealHint
                      : null,
                ),
                if (onBuySecondHint != null) ...[
                  const SizedBox(height: 6),
                  _HintButton(
                    label: 'רמז נוסף  (${EconomyConfig.hintSecondPrice} 🪙)',
                    canAfford: canAffordSecondHint && !isBusy,
                    isBusy: isBusy,
                    onTap: canAffordSecondHint && !isBusy ? onBuySecondHint : null,
                  ),
                ],
              ],
              // Stun card — only in multiplayer when user has cards
              if (canUseStunCard && onStunCard != null) ...[
                const SizedBox(height: 6),
                _StunCardButton(
                  stunCardCount: stunCardCount,
                  targets: stunTargets,
                  onStun: onStunCard!,
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
  final String label;
  final bool canAfford;
  final bool isBusy;
  final VoidCallback? onTap;

  const _HintButton({
    required this.label,
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
                label,
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

    final btn = GestureDetector(
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
    if (glow) {
      return btn
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1.0,
            end: 1.018,
            duration: 860.ms,
            curve: Curves.easeInOut,
          );
    }
    return btn;
  }
}

// ── Stun card button ──────────────────────────────────────────────────────────

class _StunCardButton extends StatelessWidget {
  final int stunCardCount;
  final List<PlayerModel> targets;
  final Future<void> Function(String targetId) onStun;

  const _StunCardButton({
    required this.stunCardCount,
    required this.targets,
    required this.onStun,
  });

  Future<void> _showTargetPicker(BuildContext context) async {
    HapticFeedback.lightImpact();
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0D1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🔒', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'בחר שחקן לחסימה',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: targets.map((p) => ListTile(
              onTap: () => Navigator.pop(ctx, p.id),
              leading: const Text('👤', style: TextStyle(fontSize: 20)),
              title: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ביטול', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await onStun(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showTargetPicker(context),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF07101F).withOpacity(0.56),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF8B4FBF).withOpacity(0.45),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              'עצור שחקן ($stunCardCount)',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFFCF9FFF),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
