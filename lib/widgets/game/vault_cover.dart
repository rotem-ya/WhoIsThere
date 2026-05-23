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
  // _anim drives the iris opening (eased)
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    if (widget.isRevealed) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant VaultCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _ctrl.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Revealed image underneath ──────────────────────────────────
          widget.child,

          // ── Iris blades ────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              if (_anim.value >= 0.995) return const SizedBox.shrink();
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _AperturePainter(progress: _anim.value),
                ),
              );
            },
          ),

          // ── Flash of light at reveal peak ──────────────────────────────
          AnimatedBuilder(
            animation: _ctrl, // linear for precise timing
            builder: (context, _) {
              final t = _ctrl.value;
              // Ramp up 0→0.38, ramp down 0.38→0.72
              final raw = t <= 0.38
                  ? t / 0.38
                  : math.max(0.0, 1.0 - (t - 0.38) / 0.34);
              final opacity = (raw * 0.60).clamp(0.0, 1.0);
              if (opacity < 0.01) return const SizedBox.shrink();
              return Opacity(
                opacity: opacity,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFE082),
                        Color(0x00FFE082),
                      ],
                      stops: [0.0, 0.40, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Improved iris painter ──────────────────────────────────────────────────────

class _AperturePainter extends CustomPainter {
  final double progress;

  static const int _bladeCount = 10;

  const _AperturePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal =
        math.sqrt(size.width * size.width + size.height * size.height);
    final outerRadius = diagonal * 0.74;

    canvas.saveLayer(rect, Paint());

    // ── Dark base ────────────────────────────────────────────────────────
    canvas.drawRect(rect, Paint()..color = const Color(0xFF07101F));

    // ── Gold metallic rotating blades ────────────────────────────────────
    final rotation = progress * math.pi * 0.52;
    final angleStep = (2 * math.pi) / _bladeCount;

    for (int i = 0; i < _bladeCount; i++) {
      final angle = i * angleStep + rotation;
      // Each blade overlaps the next by ~85% of the step
      final nextAngle = angle + angleStep * 1.85;

      // Outer corners
      final pOuter1 = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );
      final pOuter2 = Offset(
        center.dx + outerRadius * math.cos(nextAngle),
        center.dy + outerRadius * math.sin(nextAngle),
      );
      // Bezier control point curves the leading edge inward (concave)
      final midAngle = (angle + nextAngle) / 2;
      final controlRadius = outerRadius * 0.78;
      final pControl = Offset(
        center.dx + controlRadius * math.cos(midAngle),
        center.dy + controlRadius * math.sin(midAngle),
      );

      final bladePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pOuter1.dx, pOuter1.dy)
        ..quadraticBezierTo(
            pControl.dx, pControl.dy, pOuter2.dx, pOuter2.dy)
        ..close();

      // Gold metallic gradient — bright at leading edge, dark at trailing
      final gradientAngle = angle + 0.25;
      canvas.drawPath(
        bladePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(
                math.cos(gradientAngle), math.sin(gradientAngle)),
            end: Alignment(math.cos(gradientAngle + math.pi),
                math.sin(gradientAngle + math.pi)),
            colors: const [
              Color(0xFFFFF3B8), // bright gold highlight
              Color(0xFFE8C84A), // gold
              Color(0xFFD4AF37), // mid gold
              Color(0xFF8B6914), // dark gold
              Color(0xFF3A2A05), // shadow edge
            ],
            stops: const [0.0, 0.18, 0.42, 0.72, 1.0],
          ).createShader(rect),
      );

      // Thin bright seam on the leading edge
      canvas.drawLine(
        center,
        pOuter1,
        Paint()
          ..color = const Color(0xFFFFF8CC).withOpacity(0.55)
          ..strokeWidth = 0.6,
      );
    }

    // ── Punch iris hole using BlendMode.clear ────────────────────────────
    final holeRadius = progress * outerRadius;
    if (holeRadius > 0) {
      canvas.drawCircle(
          center, holeRadius, Paint()..blendMode = BlendMode.clear);
    }

    canvas.restore();

    // ── Gold + cyan chrome ring at the iris edge ──────────────────────────
    if (holeRadius > 2 && progress < 0.97) {
      final rimAlpha = (1.0 - progress).clamp(0.0, 1.0);

      // Outer gold stroke
      canvas.drawCircle(
        center,
        holeRadius + 0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFFD4AF37).withOpacity(rimAlpha * 0.85)
          ..strokeWidth = 1.4,
      );
      // Inner cyan gleam
      canvas.drawCircle(
        center,
        holeRadius - 0.8,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF87CEEB).withOpacity(rimAlpha * 0.50)
          ..strokeWidth = 0.7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePainter old) =>
      old.progress != progress;
}
