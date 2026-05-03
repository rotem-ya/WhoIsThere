import 'package:flutter/material.dart';
class AnswerSlots extends StatelessWidget {
  final String answer;

  const AnswerSlots({required this.answer});

  @override
  Widget build(BuildContext context) {
    final chars = answer.trim().characters.toList();
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
                Container(
                  width: 28,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                      width: 1,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

