import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class PremiumScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showBeams;
  final bool animate;

  const PremiumScaffold({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.showBeams = false,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageBackground),
        child: Stack(
          children: [
            Positioned.fill(
              child: _PremiumBackdrop(showBeams: showBeams, animate: animate),
            ),
            SafeArea(
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PremiumGlassCard extends GlassPanel {
  const PremiumGlassCard({
    super.key,
    required super.child,
    super.padding,
    super.radius,
  });
}

class PremiumLogo extends StatelessWidget {
  final double size;

  const PremiumLogo({super.key, this.size = 132});

  @override
  Widget build(BuildContext context) {
    final tileSize = size / 3.6;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withOpacity(0.36),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.92, end: 1.08, duration: 1800.ms),
          Transform.rotate(
            angle: -0.08,
            child: Container(
              width: size * 0.76,
              height: size * 0.76,
              padding: EdgeInsets.all(size * 0.09),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(size * 0.23),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.42),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: List.generate(9, (index) {
                  final isOpen = index == 1 || index == 4 || index == 7;
                  return Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: isOpen
                          ? Colors.white.withOpacity(0.88)
                          : Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: isOpen
                        ? const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.secondary,
                            size: 18,
                          )
                        : null,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroPuzzleMark extends StatelessWidget {
  final double size;

  const HeroPuzzleMark({super.key, this.size = 132});

  @override
  Widget build(BuildContext context) {
    return PremiumLogo(size: size);
  }
}

class PremiumPuzzlePreview extends StatelessWidget {
  final double size;

  const PremiumPuzzlePreview({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.52,
      child: PremiumLogo(size: size),
    );
  }
}

class _PremiumBackdrop extends StatefulWidget {
  final bool showBeams;
  final bool animate;

  const _PremiumBackdrop({
    required this.showBeams,
    required this.animate,
  });

  @override
  State<_PremiumBackdrop> createState() => _PremiumBackdropState();
}

class _PremiumBackdropState extends State<_PremiumBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 18.seconds);
    if (widget.animate) {
      _controller.repeat();
    }
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
