import 'package:flutter/material.dart';

/// One actionable detective tool shown in the in-game tools sheet.
///
/// Tools are self-help reveal actions (bomb, spotlight, targeted reveal,
/// fast-forward) plus hint / personal-reveal. They are pay-per-use and affect
/// the acting player's board only. [enabled] folds together affordability,
/// per-round cap and board availability; when false the row is greyed and
/// [onTap] is ignored. A [price] of 0 renders as "free".
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
