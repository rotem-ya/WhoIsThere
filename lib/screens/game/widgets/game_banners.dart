import 'package:flutter/material.dart';

import '../../../models/player_model.dart';

class GuessBanner extends StatefulWidget {
  final Map<String, dynamic> event;
  final Map<String, PlayerModel> players;

  const GuessBanner({super.key, required this.event, required this.players});

  @override
  State<GuessBanner> createState() => _GuessBannerState();
}

class _GuessBannerState extends State<GuessBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  late final Animation<double> _offsetX;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _offsetX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -9.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -9.0, end: 9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 9.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeInOut));

    final isCorrect = widget.event['isCorrect'] as bool? ?? false;
    if (!isCorrect) _shake.forward();
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerId = widget.event['playerId'] as String? ?? '';
    final guess = widget.event['guess'] as String? ?? '';
    final isCorrect = widget.event['isCorrect'] as bool? ?? false;
    final rawPlayerName = widget.players[playerId]?.name ?? '';
    final playerName = rawPlayerName.isNotEmpty ? rawPlayerName : 'שחקן';

    return AnimatedBuilder(
      animation: _offsetX,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offsetX.value, 0),
        child: child,
      ),
      child: Padding(
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
      duration: const Duration(milliseconds: 480),
    )..repeat(reverse: true);
    _borderOpacity = Tween<double>(begin: 0.28, end: 0.90).animate(
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
              width: 2.0,
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
