import 'package:flutter/material.dart';

/// Animates an integer as it tallies to a new value, so scores and point
/// totals count up smoothly instead of jumping. Drop-in replacement for a
/// static number `Text`.
///
/// The coin balance has its own richer chip ([CoinDisplay]); use this for
/// plain point / score numbers (profile, leaderboard rows, win screen).
class AnimatedCount extends StatefulWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  /// Optional formatter (e.g. add a suffix or thousands separators). Receives
  /// the interpolated integer on every frame.
  final String Function(int)? formatter;

  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.textAlign,
    this.formatter,
  });

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    // Start already showing the current value (no intro tally on first build).
    _anim = AlwaysStoppedAnimation(widget.value.toDouble());
  }

  @override
  void didUpdateWidget(AnimatedCount old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final from = _anim.value;
      _anim = Tween<double>(begin: from, end: widget.value.toDouble())
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final v = _anim.value.round();
        final text = widget.formatter?.call(v) ?? '$v';
        return Text(text, style: widget.style, textAlign: widget.textAlign);
      },
    );
  }
}
