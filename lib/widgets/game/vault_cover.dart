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

    // Fast, tactile 220ms animation for a heavy mechanical snap
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
    );

    if (widget.isRevealed) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant VaultCover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRevealed && !oldWidget.isRevealed) {
      _ctrl.forward(from: 0.0);
    }

    if (!widget.isRevealed && oldWidget.isRevealed) {
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
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The continuous underlying image slice remains untouched
            widget.child,

            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                // Remove overlay completely when fully revealed to expose the board
                if (_anim.value >= 0.995) {
                  return const SizedBox.shrink();
                }

                return CustomPaint(
                  painter: _AperturePainter(
                    progress: _anim.value,
                    focused: widget.isFocused,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  final double progress;
  final bool focused;

  static const int bladeCount = 8;

  const _AperturePainter({
    required this.progress,
    required this.focused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    final eased = Curves.easeOutCubic.transform(progress);
    final overshoot = math.sin(progress * math.pi) * 0.05;
    final openRadius = (eased + overshoot) * diagonal * 0.92;
    final rotation = eased * math.pi / bladeCount * 2.5;

    canvas.saveLayer(rect, Paint());

    // 1. Deep Graphite / Gunmetal Background
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF2A2A2A),
            Color(0xFF141414),
            Color(0xFF050505),
          ],
          radius: 1.5,
          center: Alignment.center,
        ).createShader(rect),
    );

    // 2. Glossy Metal Sweep (Neutral highlights, no neon)
    final sweep = math.sin(progress * math.pi).clamp(0.0, 1.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.05 + (0.05 * sweep)),
            Colors.white.withOpacity(0.1 + (0.1 * sweep)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        ).createShader(rect),
    );

    // 3. Overlapping Mechanical Blades (Black Chrome / Graphite)
    for (int i = 0; i < bladeCount; i++) {
      final a0 = i * 2 * math.pi / bladeCount + rotation;
      final a1 = (i + 1) * 2 * math.pi / bladeCount + rotation;
      final aMid = (a0 + a1) / 2;

      final blade = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + diagonal * math.cos(a0), center.dy + diagonal * math.sin(a0))
        ..lineTo(center.dx + diagonal * 1.15 * math.cos(aMid), center.dy + diagonal * 1.15 * math.sin(aMid))
        ..lineTo(center.dx + diagonal * math.cos(a1), center.dy + diagonal * math.sin(a1))
        ..close();

      canvas.drawPath(
        blade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: i.isEven
                ? const [Color(0xFF383838), Color(0xFF1E1E1E), Color(0xFF0A0A0A)]
                : const [Color(0xFF2C2C2C), Color(0xFF151515), Color(0xFF000000)],
          ).createShader(rect),
      );

      // Subtle metallic edge for precision-engineered look
      canvas.drawLine(
        center,
        Offset(
          center.dx + diagonal * math.cos(a0),
          center.dy + diagonal * math.sin(a0),
        ),
        Paint()
          ..color = const Color(0xFF666666).withOpacity(0.6)
          ..strokeWidth = 1.0,
      );
    }

    // 4. Center Vault Optics (Pure mechanical geometry, no glow)
    final hubRadius = size.shortestSide * 0.12;

    // Outer dark steel ring
    canvas.drawCircle(
      center,
      hubRadius * 1.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF444444).withOpacity(0.8),
    );

    // Inner shadow ring
    canvas.drawCircle(
      center,
      hubRadius * 1.4,
      Paint()..color = const Color(0xFF0A0A0A),
    );

    // Inner bright steel ring
    canvas.drawCircle(
      center,
      hubRadius * 1.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFF777777).withOpacity(0.9),
    );

    canvas.drawCircle(
      center,
      hubRadius * 0.75,
      Paint()..color = const Color(0xFF030303),
    );

    // 5. Iris Hole Opening (Clears the metal layer to expose the image slice)
    if (openRadius > 1) {
      canvas.drawPath(
        _irisHole(center, openRadius, rotation),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();

    // 6. Brushed Metal Rim exactly on the opening edge (fades as it opens)
    if (openRadius > 2 && progress < 0.98) {
      canvas.drawPath(
        _irisHole(center, openRadius, rotation),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF999999).withOpacity(0.7 * (1.0 - progress)),
      );
    }
  }

  Path _irisHole(Offset center, double radius, double rotation) {
    const sides = 8;
    final path = Path();

    for (int i = 0; i < sides; i++) {
      final angle = i * 2 * math.pi / sides + rotation;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _AperturePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.focused != focused;
  }
}

