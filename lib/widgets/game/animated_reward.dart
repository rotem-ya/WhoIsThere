import 'package:flutter/material.dart';

class AnimatedReward extends StatefulWidget {
  final int value;
  final bool isPositive;

  const AnimatedReward({
    super.key,
    required this.value,
    required this.isPositive,
  });

  @override
  State<AnimatedReward> createState() => _AnimatedRewardState();
}

class _AnimatedRewardState extends State<AnimatedReward>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  double _getScalePeak(int value) {
    final abs = value.abs();
    if (abs < 30) return 1.04;
    if (abs < 70) return 1.07;
    if (abs < 120) return 1.10;
    return 1.12;
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _scale = Tween(begin: 1.0, end: 1.0).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedReward oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      final peak = _getScalePeak(widget.value);

      _scale = TweenSequence([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: peak),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween(begin: peak, end: 1.0),
          weight: 1,
        ),
      ]).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ));

      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBig = widget.isPositive && widget.value >= 100;

    final color = widget.isPositive
        ? (isBig ? Colors.greenAccent.shade100 : Colors.greenAccent)
        : Colors.redAccent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.scale(
          scale: _scale.value,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  size: 12,
                  color: Colors.amber,
                ),
                const SizedBox(width: 2),
                Text(
                  widget.isPositive ? '+${widget.value}' : '-${widget.value}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
