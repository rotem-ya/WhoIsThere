import 'package:flutter/widgets.dart';

/// Adds a gentle depth parallax to an image: the picture drifts a few pixels
/// toward the finger and eases back when released, so a revealed photo feels
/// alive. Uses a pass-through [Listener] (not a gesture recognizer), so it
/// never steals taps or scroll from anything around it.
class ParallaxImage extends StatefulWidget {
  final Widget child;

  /// Peak drift as a fraction of the image size (0.04 = 4%). A slight overscan
  /// scale hides the edges as it drifts.
  final double magnitude;
  final BorderRadius? borderRadius;

  const ParallaxImage({
    super.key,
    required this.child,
    this.magnitude = 0.045,
    this.borderRadius,
  });

  @override
  State<ParallaxImage> createState() => _ParallaxImageState();
}

class _ParallaxImageState extends State<ParallaxImage> {
  Offset _shift = Offset.zero;
  Size _size = Size.zero;

  void _update(Offset local) {
    if (_size.width <= 0 || _size.height <= 0) return;
    final nx = (local.dx / _size.width - 0.5) * 2; // -1..1
    final ny = (local.dy / _size.height - 0.5) * 2;
    setState(() => _shift = Offset(
          -nx * widget.magnitude,
          -ny * widget.magnitude,
        ));
  }

  void _reset() => setState(() => _shift = Offset.zero);

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, c) {
        _size = Size(c.maxWidth, c.maxHeight);
        return AnimatedScale(
          scale: 1.0 + widget.magnitude * 2,
          duration: const Duration(milliseconds: 200),
          child: AnimatedSlide(
            offset: _shift,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        );
      },
    );
    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    } else {
      content = ClipRect(child: content);
    }
    return Listener(
      onPointerMove: (e) => _update(e.localPosition),
      onPointerDown: (e) => _update(e.localPosition),
      onPointerUp: (_) => _reset(),
      onPointerCancel: (_) => _reset(),
      behavior: HitTestBehavior.translucent,
      child: content,
    );
  }
}
