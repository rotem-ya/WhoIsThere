import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Full-screen animated cosmic background.
/// CustomPainter-based: deterministic particles, orbit lines, glow orbs.
/// Safe for Android — low draw call count, no image assets.
class AmbientBackground extends StatefulWidget {
  final double intensity;
  final bool showGrid;
  final bool showOrbits;
  final bool showParticles;
  final bool goldAccent;
  final bool animate;

  const AmbientBackground({
    super.key,
    this.intensity = 1.0,
    this.showGrid = false,
    this.showOrbits = true,
    this.showParticles = true,
    this.goldAccent = false,
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
      duration: const Duration(seconds: 24),
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
      // child is built once and passed through; painter controls all animation.
      child: const SizedBox.expand(),
      builder: (context, child) => CustomPaint(
        painter: _CosmicPainter(
          progress: _controller.value,
          intensity: widget.intensity,
          showGrid: widget.showGrid,
          showOrbits: widget.showOrbits,
          showParticles: widget.showParticles,
          goldAccent: widget.goldAccent,
        ),
        child: child,
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────

class _CosmicPainter extends CustomPainter {
  final double progress;
  final double intensity;
  final bool showGrid;
  final bool showOrbits;
  final bool showParticles;
  final bool goldAccent;

  static const int _count = 18;
  static final List<_Particle> _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    final rng = math.Random(42);
    return List.generate(
      _count,
      (_) => _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        r: 1.2 + rng.nextDouble() * 1.8,
        speed: 0.15 + rng.nextDouble() * 0.25,
        phase: rng.nextDouble() * math.pi * 2,
        gold: rng.nextDouble() < 0.35,
      ),
    );
  }

  _CosmicPainter({
    required this.progress,
    required this.intensity,
    required this.showGrid,
    required this.showOrbits,
    required this.showParticles,
    required this.goldAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * math.pi * 2;
    _paintOrbs(canvas, size, t);
    if (showGrid) _paintGrid(canvas, size, t);
    if (showOrbits) _paintOrbits(canvas, size, t);
    if (showParticles) _paintParticles(canvas, size, t);
  }

  void _paintOrbs(Canvas canvas, Size size, double t) {
    _drawOrb(
      canvas,
      Offset(
        size.width - 70 + math.cos(t * 0.7) * 14,
        -90 + math.sin(t * 0.5) * 18,
      ),
      260,
      AppColors.accent.withOpacity(0.22 * intensity),
    );
    _drawOrb(
      canvas,
      Offset(
        -80 + math.sin(t * 0.6) * 16,
        size.height - 120 + math.cos(t * 0.4) * 20,
      ),
      310,
      (goldAccent ? AppColors.primary : AppColors.secondary)
          .withOpacity(0.17 * intensity),
    );
  }

  void _drawOrb(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _paintGrid(Canvas canvas, Size size, double t) {
    final p = Paint()
      ..color = Colors.white
          .withOpacity((0.044 + math.sin(t) * 0.009) * intensity)
      ..strokeWidth = 0.8;
    const gap = 42.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  void _paintOrbits(Canvas canvas, Size size, double t) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.36;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    for (int k = 0; k < 2; k++) {
      final r = 100.0 + k * 80;
      final op = (0.052 + math.sin(t + k * 1.4) * 0.014) * intensity;
      stroke.color =
          (goldAccent ? AppColors.primary : AppColors.accent).withOpacity(op);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: r * 2.4,
          height: r * 0.84,
        ),
        stroke,
      );
      // travelling dot along orbit
      final angle = t * (k == 0 ? 0.34 : -0.27);
      final dotOp = (0.40 + math.sin(t * 2 + k) * 0.16) * intensity;
      canvas.drawCircle(
        Offset(cx + math.cos(angle) * r * 1.2, cy + math.sin(angle) * r * 0.42),
        2.0,
        Paint()
          ..color = (goldAccent ? AppColors.primary : AppColors.accent)
              .withOpacity(dotOp),
      );
    }
  }

  void _paintParticles(Canvas canvas, Size size, double t) {
    final positions = List<Offset>.filled(_count, Offset.zero);

    for (int i = 0; i < _count; i++) {
      final p = _particles[i];
      final px =
          p.x * size.width + math.sin(t * p.speed + p.phase) * 7 * intensity;
      final py =
          p.y * size.height + math.cos(t * p.speed * 0.7 + p.phase) * 5;
      final op =
          (0.26 + math.sin(t * p.speed + p.phase) * 0.15) * intensity;
      canvas.drawCircle(
        Offset(px, py),
        p.r,
        Paint()
          ..color = (p.gold || goldAccent ? AppColors.primary : AppColors.accent)
              .withOpacity(op),
      );
      positions[i] = Offset(px, py);
    }

    // Connection lines between nearby particles (cap at 6)
    final line = Paint()..strokeWidth = 0.5;
    int drawn = 0;
    for (int i = 0; i < _count && drawn < 6; i++) {
      for (int j = i + 1; j < _count && drawn < 6; j++) {
        final d = (positions[i] - positions[j]).distance;
        if (d < 88) {
          line.color =
              AppColors.accent.withOpacity((1 - d / 88) * 0.10 * intensity);
          canvas.drawLine(positions[i], positions[j], line);
          drawn++;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicPainter old) =>
      old.progress != progress;
}

// ── Data ───────────────────────────────────────────────────────────────────

class _Particle {
  final double x, y, r, speed, phase;
  final bool gold;
  const _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.speed,
    required this.phase,
    required this.gold,
  });
}
