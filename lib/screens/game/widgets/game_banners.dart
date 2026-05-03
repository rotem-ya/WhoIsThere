import 'package:flutter/material.dart';

import '../../../models/player_model.dart';

class GuessBanner extends StatelessWidget {
  final Map<String, dynamic> event;
  final Map<String, PlayerModel> players;

  const GuessBanner({required this.event, required this.players});

  @override
  Widget build(BuildContext context) {
    final playerId = event['playerId'] as String? ?? '';
    final guess = event['guess'] as String? ?? '';
    final isCorrect = event['isCorrect'] as bool? ?? false;
    final playerName = players[playerId]?.name ?? playerId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isCorrect
              ? const Color(0xFF1B5E20).withOpacity(0.92)
              : const Color(0xFF7F0000).withOpacity(0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCorrect
                ? Colors.green.shade400.withOpacity(0.5)
                : Colors.red.shade400.withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                '$playerName ניחש: "$guess"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isCorrect ? 'נכון! ✓' : 'לא נכון ✗',
              style: TextStyle(
                color: isCorrect ? Colors.greenAccent : Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

