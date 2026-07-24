import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A card that tilts in 3D toward the finger as you press or drag across it,
/// then springs back flat on release — a lightweight "premium depth" effect
/// with no sensor plugins. Also handles the tap (with a light press-scale), so
/// it can drop in wherever a tappable card lives.
///
/// Honors the OS "reduce motion" setting by skipping the tilt (it still taps
/// and scales).
class TiltCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double maxTilt; // radians at the card edge
  final double pressScale;

  const TiltCard({
    super.key,
    required this.child,
    this.onTap,
    this.maxTilt = 0.16,
    this.pressScale = 0.97,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset? _local; // null = not touching → resting flat
  Size _size = Size.zero;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _touch(Offset p) => setState(() {
        _pressed = true;
        _local = p;
      });

  void _release() => setState(() {
        _pressed = false;
        _local = null;
      });

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        // Target tilt: rotateY from horizontal offset, rotateX from vertical.
        double ry = 0, rx = 0;
        if (!reduce && _local != null && _size.width > 0 && _size.height > 0) {
          final dx = (_local!.dx / _size.width - 0.5).clamp(-0.5, 0.5);
          final dy = (_local!.dy / _size.height - 0.5).clamp(-0.5, 0.5);
          ry = dx * 2 * widget.maxTilt;
          rx = -dy * 2 * widget.maxTilt;
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            HapticFeedback.selectionClick();
            _touch(d.localPosition);
          },
          onTapUp: (_) {
            _release();
            widget.onTap!();
          },
          onTapCancel: _release,
          onPanStart: (d) => _touch(d.localPosition),
          onPanUpdate: (d) => _touch(d.localPosition),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          // Follow the finger quickly; spring back slower when released.
          child: TweenAnimationBuilder<Offset>(
            tween: Tween<Offset>(end: Offset(ry, rx)),
            duration: Duration(milliseconds: _local != null ? 80 : 260),
            curve: _local != null ? Curves.easeOut : Curves.easeOutBack,
            builder: (context, tilt, child) {
              final scale = _pressed ? widget.pressScale : 1.0;
              final m = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(tilt.dy)
                ..rotateY(tilt.dx)
                ..scale(scale, scale);
              return Transform(
                alignment: Alignment.center,
                transform: m,
                child: child,
              );
            },
            child: widget.child,
          ),
        );
      },
    );
  }
}
