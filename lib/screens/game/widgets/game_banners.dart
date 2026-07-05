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
  late final AnimationController _ctrl;
  late final Animation<double> _offsetX;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final isCorrect = widget.event['isCorrect'] as bool? ?? false;

    if (!isCorrect) {
      // Wrong guess: horizontal shake
      _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
      _offsetX = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -9.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -9.0, end: 9.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 9.0, end: -6.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
      ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
      _scale = AlwaysStoppedAnimation<double>(1.0);
    } else {
      // Correct guess: scale slam — punches in, settles
      _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
      _offsetX = AlwaysStoppedAnimation<double>(0.0);
      _scale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.05), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 3),
      ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    }
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerId = widget.event['playerId'] as String? ?? '';
    final isCorrect = widget.event['isCorrect'] as bool? ?? false;
    final rawPlayerName = widget.players[playerId]?.name ?? '';
    final playerName = rawPlayerName.isNotEmpty ? rawPlayerName : 'שחקן';

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(_offsetX.value, 0),
        child: Transform.scale(
          scale: _scale.value,
          child: child,
        ),
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
                  isCorrect ? '$playerName ניחש נכון!' : '$playerName ניסה לנחש',
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
  // Endgame threat: render a red, fast-pulsing "about to solve!" alarm to
  // pressure the player into guessing first.
  final bool isThreat;

  const BotTypingBanner({
    super.key,
    required this.botName,
    required this.typedSoFar,
    this.isThreat = false,
  });

  @override
  State<BotTypingBanner> createState() => _BotTypingBannerState();
}

class _BotTypingBannerState extends State<BotTypingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late Animation<double> _borderOpacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _pulseDuration)
      ..repeat(reverse: true);
    _borderOpacity = Tween<double>(begin: 0.28, end: 0.90).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  Duration get _pulseDuration =>
      widget.isThreat ? const Duration(milliseconds: 300) : const Duration(milliseconds: 480);

  @override
  void didUpdateWidget(BotTypingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Speed the pulse up when the banner escalates to a threat mid-life.
    if (widget.isThreat != oldWidget.isThreat) {
      _pulse.duration = _pulseDuration;
      _pulse
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTyping = widget.typedSoFar.isNotEmpty;

    if (widget.isThreat) {
      return AnimatedBuilder(
        animation: _borderOpacity,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF7F0000).withOpacity(0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.redAccent.withOpacity(0.40 + _borderOpacity.value * 0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(_borderOpacity.value * 0.55),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🚨', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${widget.botName} עומד לפתור! נחש מהר!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _borderOpacity,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.90),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.11),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A8AB5).withOpacity(_borderOpacity.value),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isTyping
                      ? '${widget.botName} מקליד...'
                      : '${widget.botName} חושב...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
