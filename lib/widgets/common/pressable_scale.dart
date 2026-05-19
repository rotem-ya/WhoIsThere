import 'package:flutter/material.dart';

/// Wraps [child] with a press-depth scale: 90 ms down, 140 ms release.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final VoidCallback? onTap;

  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.93,
    this.onTap,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Repeating opacity breathe between [minOpacity] and [maxOpacity].
class SoftPulse extends StatefulWidget {
  final Widget child;
  final double minOpacity;
  final double maxOpacity;
  final Duration period;

  const SoftPulse({
    super.key,
    required this.child,
    this.minOpacity = 0.30,
    this.maxOpacity = 0.70,
    this.period = const Duration(milliseconds: 1800),
  });

  @override
  State<SoftPulse> createState() => _SoftPulseState();
}

class _SoftPulseState extends State<SoftPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: widget.minOpacity, end: widget.maxOpacity)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _anim, child: widget.child);
  }
}
