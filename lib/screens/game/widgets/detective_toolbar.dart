import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/feedback_service.dart';
import '../../../widgets/economy/coin_icon.dart';

/// One actionable detective tool shown in the in-game toolbar.
///
/// Tools are self-help reveal actions (bomb, spotlight, targeted reveal,
/// fast-forward). They are pay-per-use and affect the acting player's board
/// only. [enabled] folds together affordability, per-round cap and board
/// availability; when false the chip is greyed and [onTap] is ignored.
class DetectiveAction {
  final String emoji;
  final String label;
  final int price;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const DetectiveAction({
    required this.emoji,
    required this.label,
    required this.price,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
}

/// A compact horizontal toolbar of detective tools, rendered above the guess
/// button. Gives the player something active to do every round (especially in
/// solo), turning passive watching into spending decisions.
class DetectiveToolbar extends StatelessWidget {
  final List<DetectiveAction> actions;

  const DetectiveToolbar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(child: _ToolChip(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  final DetectiveAction action;

  const _ToolChip({required this.action});

  @override
  Widget build(BuildContext context) {
    final on = action.enabled;
    return GestureDetector(
      onTap: on
          ? () {
              HapticFeedback.lightImpact();
              FeedbackService.click();
              action.onTap();
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: on ? 1.0 : 0.40,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.56),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: action.color.withOpacity(on ? 0.45 : 0.16),
              width: 0.9,
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: action.color.withOpacity(0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(action.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 1),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: action.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${action.price}',
                    style: TextStyle(
                      color: action.color.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const CoinIcon(size: 11),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
