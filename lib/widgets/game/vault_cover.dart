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

    // Adjusted to 600ms for a more obvious, satisfying mechanical aperture feel
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutExpo,
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
                // Remove overlay completely when fully revealed
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
    final overshoot = math.sin(progress * math.pi) * 0.10;
    final openRadius = (eased + overshoot) * diagonal * 0.92;
    final rotation = eased * math.pi / bladeCount * 3.2;

    canvas.saveLayer(rect, Paint());

    // 1. Vivid Deep Camera Glass Background
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: const [
            Color(0xFF004488),
            Color(0xFF001133),
            Color(0xFF000511),
          ],
          radius: 1.5,
          center: Alignment.center,
        ).createShader(rect),
    );

    // 2. Diagonal Lens Glass Sweep / Glare
    final sweep = math.sin(progress * math.pi).clamp(0.0, 1.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            const Color(0xFF00FFFF).withOpacity(0.15 + (0.2 * sweep)),
            const Color(0xFF00BFFF).withOpacity(0.3 + (0.3 * sweep)),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        ).createShader(rect),
    );

    // 3. Premium Cyan/Electric Blue Aperture Blades
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
                ? const [Color(0xFF0099FF), Color(0xFF0055BB), Color(0xFF002266)]
                : const [Color(0xFF0088EE), Color(0xFF0044AA), Color(0xFF001144)],
          ).createShader(rect),
      );

      // Bright Cyan Blade Edges for Mechanical Precision
      canvas.drawLine(
        center,
        Offset(
          center.dx + diagonal * math.cos(a0),
          center.dy + diagonal * math.sin(a0),
        ),
        Paint()
          ..color = const Color(0xFF00FFFF).withOpacity(0.6)
          ..strokeWidth = 1.2,
      );
    }

    // 4. Center Camera Lens Hub (No lock icon, pure optics)
    final hubRadius = size.shortestSide * 0.12;

    // Outer cyan glowing ring
    canvas.drawCircle(
      center,
      hubRadius * 1.8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF00E5FF).withOpacity(0.5),
    );

    // Inner dark pupil
    canvas.drawCircle(
      center,
      hubRadius * 1.4,
      Paint()..color = const Color(0xFF00081A),
    );

    // Inner bright optical ring
    canvas.drawCircle(
      center,
      hubRadius * 1.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF00FFFF).withOpacity(0.8),
    );

    canvas.drawCircle(
      center,
      hubRadius * 0.75,
      Paint()..color = const Color(0xFF00030A),
    );

    // 5. Iris Hole Opening (Clears the layer to expose the image slice)
    if (openRadius > 1) {
      canvas.drawPath(
        _irisHole(center, openRadius, rotation),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();

    // 6. Glowing Cyan Edge exactly on the opening rim
    if (openRadius > 2 && progress < 0.96) {
      canvas.drawPath(
        _irisHole(center, openRadius, rotation),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = const Color(0xFF00FFFF).withOpacity(0.9 * (1.0 - progress * 0.35)),
      );
    }

    // 7. Bright Camera Exposure Flash (Replaces the dark sweep)
    if (progress > 0.05 && progress < 0.90) {
      final flash = math.sin(((progress - 0.05) / 0.85).clamp(0.0, 1.0) * math.pi);
      final flashRadius = math.max(8.0, openRadius * 0.85);

      canvas.drawCircle(
        center,
        flashRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withOpacity(0.7 * flash),
              const Color(0xFF00FFFF).withOpacity(0.4 * flash),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(
            Rect.fromCircle(center: center, radius: flashRadius),
          ),
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
