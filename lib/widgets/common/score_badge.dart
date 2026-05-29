import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class ScoreBadge extends StatelessWidget {
  final int score;
  final bool isCurrentTurn;
  final bool isEliminated;
  final bool isHost;

  const ScoreBadge({
    super.key,
    required this.score,
    this.isCurrentTurn = false,
    this.isEliminated = false,
    this.isHost = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isEliminated
            ? Colors.grey.shade300
            : isCurrentTurn
                ? AppColors.primary
                : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentTurn ? AppColors.primary : AppColors.pieceSlotEmpty,
          width: 2,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost) const Text('⭐ ', style: TextStyle(fontSize: 11)),
          Icon(
            Icons.star_rounded,
            size: 16,
            color: isCurrentTurn ? Colors.white : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            '$score',
            style: TextStyle(
              color: isCurrentTurn ? Colors.white : AppColors.darkBlue,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    )
        .animate(target: isCurrentTurn ? 1 : 0)
        .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08));
  }
}
