import 'package:flutter/material.dart';

import '../../../core/theme/app_styles.dart';
import '../../../widgets/game/letter_bank_input.dart' show stripGeresh;

class AnswerSlots extends StatelessWidget {
  final String answer;
  final bool isMyTurn;

  const AnswerSlots({required this.answer, this.isMyTurn = false});

  @override
  Widget build(BuildContext context) {
    final chars = stripGeresh(answer).trim().characters.toList();
    if (chars.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            for (final char in chars)
              if (char.trim().isEmpty)
                const SizedBox(width: 12)
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  width: 28,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isMyTurn
                        ? AppStyles.cyanGlow.withOpacity(0.12)
                        : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isMyTurn
                          ? AppStyles.cyanGlow.withOpacity(0.55)
                          : Colors.white.withOpacity(0.28),
                      width: isMyTurn ? 1.4 : 1.0,
                    ),
                    boxShadow: isMyTurn
                        ? [
                            BoxShadow(
                              color: AppStyles.cyanGlow.withOpacity(0.18),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

