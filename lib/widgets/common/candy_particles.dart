import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/candy_theme.dart';

/// A cheap, ambient layer of slowly drifting translucent "bokeh" dots — a touch
/// of life behind menu screens that reads premium without stealing attention.
/// One controller, one CustomPaint, no packages. Drop it behind page content.
class CandyParticles extends StatefulWidget {
  final int count;
  final double opacity;

  const CandyParticles({super.key, this.count = 14, this.opacity = 1.0});

  @override
  State<CandyParticles> createState() => _CandyParticlesState();
}

class _CandyParticlesState extends State<CandyParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_P> _dots;

  static const _palette = [
    Candy.teal,
    Candy.pink,
    Candy.tangerine,
    Candy.gold,
    Candy.grape,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    // Deterministic seed so the field is stable across rebuilds (no Math.random
    // resehuffle each frame). Seed is fixed — variety comes from the index.
    final rng = math.Random(7);
    _dots = List.generate(widget.count, (i) {
      return _P(
        x: rng.nextDouble(),
        baseY: rng.nextDouble(),
        r: 6 + rng.nextDouble() * 26,
        speed: 0.3 + rng.nextDouble() * 0.8,
        drift: (rng.nextDouble() - 0.5) * 0.12,
        phase: rng.nextDouble(),
        color: _palette[i % _palette.length],
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ParticlesPainter(_dots, _ctrl.value, widget.opacity),
          ),
        ),
      ),
    );
  }
}

class _P {
  final double x, baseY, r, speed, drift, phase;
  final Color color;
  const _P({
    required this.x,
    required this.baseY,
    required this.r,
    required this.speed,
    required this.drift,
    required this.phase,
    required this.color,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_P> dots;
  final double t;
  final double opacity;

  _ParticlesPainter(this.dots, this.t, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dots) {
      // Drift upward slowly and wrap; gentle horizontal sway.
      final prog = (d.baseY - (t * d.speed) + d.phase) % 1.0;
      final y = prog * (size.height + 80) - 40;
      final sway = math.sin((t + d.phase) * 2 * math.pi) * d.drift;
      final x = ((d.x + sway) % 1.0) * size.width;
      // Fade in/out near the edges of its lifecycle.
      final edge = (prog < 0.12)
          ? prog / 0.12
          : (prog > 0.88 ? (1 - prog) / 0.12 : 1.0);
      final op = (0.10 * opacity * edge).clamp(0.0, 1.0);
      if (op <= 0) continue;
      final paint = Paint()
        ..color = d.color.withOpacity(op)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d.r * 0.5);
      canvas.drawCircle(Offset(x, y), d.r, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.t != t;
}
