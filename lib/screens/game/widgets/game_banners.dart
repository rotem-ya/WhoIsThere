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
    final rawPlayerName = players[playerId]?.name ?? '';
    final playerName = rawPlayerName.isNotEmpty ? rawPlayerName : 'שחקן';

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


class BotTypingBanner extends StatefulWidget {
  final String botName;
  final String typedSoFar;

  const BotTypingBanner({
    super.key,
    required this.botName,
    required this.typedSoFar,
  });

  @override
  State<BotTypingBanner> createState() => _BotTypingBannerState();
}

class _BotTypingBannerState extends State<BotTypingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _borderOpacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _borderOpacity = Tween<double>(begin: 0.18, end: 0.65).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTyping = widget.typedSoFar.isNotEmpty;

    return AnimatedBuilder(
      animation: _borderOpacity,
      builder: (context, child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF87CEEB).withOpacity(_borderOpacity.value),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isTyping ? '${widget.botName} מקליד...' : '${widget.botName} חושב...',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (isTyping)
            Text(
              '"${widget.typedSoFar}" |',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            )
          else
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}
