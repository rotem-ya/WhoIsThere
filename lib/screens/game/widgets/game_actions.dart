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
import '../../../widgets/economy/coin_icon.dart';
import 'detective_toolbar.dart';
import 'game_tools_sheet.dart';

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
  // Personal tile reveal purchase (this-player-only). Disabled when null.
  final VoidCallback? onBuyReveal;
  final int revealBuyPrice;
  final int revealBuyCount;
  final int maxRevealBuys;
  // Detective reveal tools (bomb / spotlight / targeted / fast-forward).
  final List<DetectiveAction> detectiveActions;

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
    this.onBuyReveal,
    this.revealBuyPrice = 0,
    this.revealBuyCount = 0,
    this.maxRevealBuys = 5,
    this.detectiveActions = const [],
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

    // All spend-to-help tools (detective reveals + hint + personal reveal) are
    // consolidated into a single bottom sheet opened from one "כלים" button.
    // This keeps the play screen tidy and the board image large.
    final tools = <DetectiveAction>[...detectiveActions];
    const _toolColor = Color(0xFF6FB0CF);
    final showHint = GameConstants.hintsEnabled &&
        isSolo &&
        onRevealHint != null &&
        totalTiles > 0 &&
        revealedCount >= totalTiles * GameConstants.hintRevealThreshold;
    if (showHint) {
      final canHint = purchasedHintCount >= 1 || (canAffordFirstHint && !isBusy);
      tools.add(DetectiveAction(
        emoji: '💡',
        label: purchasedHintCount >= 1 ? 'ראה רמז' : 'רמז',
        price: purchasedHintCount >= 1 ? 0 : EconomyConfig.hintFirstPrice,
        color: _toolColor,
        enabled: canHint,
        onTap: onRevealHint ?? () {},
      ));
      if (onBuySecondHint != null) {
        final canSecond = canAffordSecondHint && !isBusy;
        tools.add(DetectiveAction(
          emoji: '💡',
          label: 'רמז נוסף',
          price: EconomyConfig.hintSecondPrice,
          color: _toolColor,
          enabled: canSecond,
          onTap: onBuySecondHint ?? () {},
        ));
      }
    }
    if (revealBuyCount < maxRevealBuys) {
      final canReveal = onBuyReveal != null && !isBusy;
      tools.add(DetectiveAction(
        emoji: '🃏',
        label: 'חשוף קלף ($revealBuyCount/$maxRevealBuys)',
        price: revealBuyPrice,
        color: _toolColor,
        enabled: canReveal,
        onTap: onBuyReveal ?? () {},
      ));
    }
    final enabledToolCount = tools.where((t) => t.enabled).length;

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
                reward: null,
              ),
              // Shrinking early-guess bonus meter: a bar that depletes (and
              // shifts green→amber→red) as more of the board is revealed, making
              // the decaying reward feel urgent. Hides itself once the bonus is 0.
              if (showReward) ...[
                const SizedBox(height: 6),
                _RewardMeter(
                  revealedCount: revealedCount,
                  totalTiles: totalTiles,
                  bonus: earlyBonus,
                ),
              ],
              // All spend-to-help tools behind one compact button → opens a
              // tidy sheet. Keeps the board large and the screen uncluttered.
              if (tools.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ToolsButton(
                  toolCount: enabledToolCount,
                  onTap: () => showGameToolsSheet(context, tools),
                ),
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

/// Compact pill for secondary self-help actions (hint / personal reveal). Much
/// smaller than the old full-width buttons so several fit on one wrapping row,
/// leaving the board image more room.
/// Single compact button that opens the tools sheet (bomb / spotlight /
/// targeted / fast-forward / hint / reveal). [toolCount] shows how many are
/// currently affordable.
class _ToolsButton extends StatelessWidget {
  final int toolCount;
  final VoidCallback onTap;

  const _ToolsButton({required this.toolCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FeedbackService.click();
        onTap();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF07101F).withOpacity(0.56),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF4A8BAA).withOpacity(0.32),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛠️', style: TextStyle(fontSize: 15)),
            const SizedBox(width: 7),
            const Text(
              'תחבולות',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Color(0xFF6FB0CF),
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (toolCount > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF20A8E0).withOpacity(0.25),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$toolCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
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

// ── Early-guess reward meter ──────────────────────────────────────────────────

/// A slim bar that visualises the decaying early-guess bonus. It empties (and
/// recolours green→amber→red) continuously as the board is revealed, so guessing
/// early feels rewarding. The numeric bonus still steps by tier; the bar gives
/// the smooth "act now" pressure. Purely cosmetic — reads board state only.
class _RewardMeter extends StatelessWidget {
  final int revealedCount;
  final int totalTiles;
  final int bonus;

  const _RewardMeter({
    required this.revealedCount,
    required this.totalTiles,
    required this.bonus,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        totalTiles <= 0 ? 1.0 : (revealedCount / totalTiles).clamp(0.0, 1.0);
    // The bonus is positive only while the reveal ratio is within tier 4
    // (≤ 80%); deplete the bar to empty exactly at that point.
    final cutoff = EconomyConfig.earlyGuessTier4MaxRatio;
    final fill = cutoff <= 0 ? 0.0 : (1.0 - ratio / cutoff).clamp(0.0, 1.0);
    final Color barColor = fill > 0.6
        ? const Color(0xFF34D399) // green — plenty of bonus left
        : fill > 0.3
            ? const Color(0xFFFBBF24) // amber — running down
            : const Color(0xFFF87171); // red — almost gone

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'בונוס ניחוש מוקדם',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '+$bonus',
              style: TextStyle(
                color: barColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 2),
            const CoinIcon(size: 13),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: Colors.white.withOpacity(0.12),
            child: Align(
              alignment: Alignment.centerRight,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                widthFactor: fill,
                child: Container(
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: barColor.withOpacity(0.6), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
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
