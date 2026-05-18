import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Full-screen ambient background: slow-drifting glow orbs + subtle grid.
/// Place as Positioned.fill inside a Stack behind screen content.
class AmbientBackground extends StatefulWidget {
  final bool showBeams;
  final bool animate;

  const AmbientBackground({
    super.key,
    this.showBeams = false,
    this.animate = true,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        return Stack(
          children: [
            Positioned(
              top: -90 + math.sin(t) * 18,
              right: -70 + math.cos(t) * 12,
              child: _GlowOrb(
                size: 260,
                color: AppColors.accent.withOpacity(0.22),
              ),
            ),
            Positioned(
              bottom: -120 + math.cos(t) * 20,
              left: -80 + math.sin(t) * 16,
              child: _GlowOrb(
                size: 310,
                color: AppColors.secondary.withOpacity(0.20),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  opacity: 0.07 + math.sin(t) * 0.015,
                  showBeams: widget.showBeams,
                  phase: t,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double opacity;
  final bool showBeams;
  final double phase;

  const _GridPainter({
    required this.opacity,
    required this.showBeams,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    if (showBeams) {
      final beamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            AppColors.accent.withOpacity(0),
            AppColors.accent.withOpacity(0.18),
            AppColors.secondary.withOpacity(0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..strokeWidth = 2.5;
      final y = (math.sin(phase) * 0.5 + 0.5) * size.height;
      canvas.drawLine(
          Offset(-40, y), Offset(size.width + 40, y - 140), beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.opacity != opacity ||
      oldDelegate.showBeams != showBeams ||
      oldDelegate.phase != phase;
}
