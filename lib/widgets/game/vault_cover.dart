import 'dart:math' as math;
import 'package:flutter/material.dart';

class VaultCover extends StatefulWidget {
  final bool isRevealed;
  final bool isFocused;
  final Widget child;

  const VaultCover({
    super.key,
    required this.isRevealed,
    required this.child,
    this.isFocused = false,
  });

  @override
  State<VaultCover> createState() => _VaultCoverState();
}

class _VaultCoverState extends State<VaultCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (widget.isRevealed) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant VaultCover old) {
    super.didUpdateWidget(old);
    if (widget.isRevealed && !old.isRevealed) _ctrl.forward(from: 0.0);
    if (!widget.isRevealed && old.isRevealed) _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        border: Border.all(
          color: (widget.isFocused && !widget.isRevealed)
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.04),
          width: 0.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                if (_anim.value >= 1.0) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _VaultDoorPainter(progress: _anim.value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultDoorPainter extends CustomPainter {
  final double progress;

  const _VaultDoorPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.height / 2;
    final retract = progress * half;

    // Top panel slides up, bottom panel slides down
    _drawPanel(canvas, size, Rect.fromLTWH(0, -retract, size.width, half));
    _drawPanel(canvas, size, Rect.fromLTWH(0, half + retract, size.width, half));

    // Hairline gap seam — visible mid-animation, fades at start and end
    if (retract > 0.5) {
      final gapOpacity = math.sin(progress * math.pi) * 0.14;
      canvas.drawLine(
        Offset(0, half),
        Offset(size.width, half),
        Paint()
          ..color = Colors.white.withOpacity(gapOpacity.clamp(0.0, 0.14))
          ..strokeWidth = 0.5,
      );
    }
  }

  void _drawPanel(Canvas canvas, Size size, Rect rect) {
    final bounds = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = const Color(0xFF263848));

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.transparent,
            Colors.black.withOpacity(0.05),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bounds),
    );

    final brushPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.55;
    for (var y = rect.top + 1.5; y < rect.bottom; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), brushPaint);
    }

    // Glossy top-edge specular catch
    canvas.drawLine(
      Offset(0, rect.top + 0.5),
      Offset(size.width, rect.top + 0.5),
      Paint()
        ..color = Colors.white.withOpacity(0.10)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _VaultDoorPainter old) =>
      old.progress != progress;
}
