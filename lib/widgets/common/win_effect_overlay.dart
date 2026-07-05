import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/win_effect.dart';

/// Plays a [WinEffect]'s particle animation, filling its parent. Drop it into a
/// Stack (Positioned.fill) on the win screen, or in a SizedBox for a preview.
/// Renders nothing for the 'none' effect.
class WinEffectOverlay extends StatefulWidget {
  final String effectId;
  final int particleCount;

  const WinEffectOverlay({
    super.key,
    required this.effectId,
    this.particleCount = 40,
  });

  @override
  State<WinEffectOverlay> createState() => _WinEffectOverlayState();
}

class _WinEffectOverlayState extends State<WinEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _buildParticles();
  }

  @override
  void didUpdateWidget(covariant WinEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effectId != widget.effectId ||
        oldWidget.particleCount != widget.particleCount) {
      _buildParticles();
    }
  }

  void _buildParticles() {
    final rnd = math.Random(widget.effectId.hashCode);
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle(
        x: rnd.nextDouble(),
        size: 8 + rnd.nextDouble() * 12,
        phase: rnd.nextDouble(),
        speed: 0.6 + rnd.nextDouble() * 0.8,
        drift: (rnd.nextDouble() - 0.5) * 0.3,
        spin: (rnd.nextDouble() - 0.5) * 6,
        colorIndex: rnd.nextInt(1 << 16),
        angle: rnd.nextDouble() * math.pi * 2,
        burstReach: 0.45 + rnd.nextDouble() * 0.55,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effect = winEffectFor(widget.effectId);
    if (effect.isNone) return const SizedBox.shrink();

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _WinEffectPainter(
              effect: effect,
              particles: _particles,
              t: _controller.value,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1 horizontal start
  final double size;
  final double phase; // 0..1 offset into the loop
  final double speed;
  final double drift; // horizontal sway amount
  final double spin;
  final int colorIndex;
  final double angle; // radians — burst direction
  final double burstReach; // 0..1 — how far this particle flies in a burst

  const _Particle({
    required this.x,
    required this.size,
    required this.phase,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.colorIndex,
    required this.angle,
    required this.burstReach,
  });
}

class _WinEffectPainter extends CustomPainter {
  final WinEffect effect;
  final List<_Particle> particles;
  final double t;

  _WinEffectPainter({
    required this.effect,
    required this.particles,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Looping progress 0..1 (per-particle phase + speed).
      final prog = (t * p.speed + p.phase) % 1.0;

      final double x;
      final double y;
      double opacity;

      switch (effect.motion) {
        case WinEffectMotion.burst:
          // Radiate from the centre, ease-out, with a little gravity droop.
          final cx = size.width / 2;
          final cy = size.height * 0.42;
          final eased = 1 - math.pow(1 - prog, 2).toDouble();
          final dist = eased * p.burstReach * size.shortestSide * 0.95;
          x = cx + math.cos(p.angle) * dist;
          y = cy + math.sin(p.angle) * dist + prog * prog * size.height * 0.18;
          opacity = (1 - prog).clamp(0.0, 1.0);
          break;
        case WinEffectMotion.rise:
          final travel = size.height + p.size * 2;
          y = size.height - prog * travel;
          final sway = math.sin((prog + p.phase) * math.pi * 4) * p.drift;
          x = ((p.x + sway) % 1.0) * size.width;
          opacity = _fade(prog);
          break;
        case WinEffectMotion.fall:
          final travel = size.height + p.size * 2;
          y = prog * travel - p.size;
          final sway = math.sin((prog + p.phase) * math.pi * 4) * p.drift;
          x = ((p.x + sway) % 1.0) * size.width;
          opacity = _fade(prog);
          break;
      }

      if (effect.emoji != null) {
        _paintEmoji(canvas, effect.emoji!, x, y, p, opacity);
      } else {
        _paintShape(canvas, x, y, p, prog, opacity);
      }
    }
  }

  // Fade in at the start, fade out at the end of the loop.
  double _fade(double prog) => (prog < 0.1
          ? prog / 0.1
          : prog > 0.85
              ? (1 - prog) / 0.15
              : 1.0)
      .clamp(0.0, 1.0);

  void _paintShape(
      Canvas canvas, double x, double y, _Particle p, double prog, double opacity) {
    final colors = effect.colors;
    final color = colors[p.colorIndex % colors.length].withOpacity(opacity);
    canvas.save();
    canvas.translate(x, y);
    final paint = Paint()..color = color;
    switch (effect.shape) {
      case WinEffectShape.ring:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
        break;
      case WinEffectShape.circle:
        // A spark with a soft glow (used by fireworks / gold).
        canvas.drawCircle(Offset.zero, p.size / 2.4, paint);
        canvas.drawCircle(
            Offset.zero,
            p.size / 1.4,
            Paint()..color = color.withOpacity(opacity * 0.30));
        break;
      case WinEffectShape.rect:
        canvas.rotate((prog * p.spin) * math.pi);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.5),
            const Radius.circular(1.5),
          ),
          paint,
        );
        break;
    }
    canvas.restore();
  }

  void _paintEmoji(
      Canvas canvas, String emoji, double x, double y, _Particle p, double opacity) {
    final tp = TextPainter(
      text: TextSpan(text: emoji, style: TextStyle(fontSize: p.size * 1.6)),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(x - tp.width / 2, y - tp.height / 2);
    // Emoji can't take opacity directly; approximate with a layer.
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, tp.width, tp.height),
      Paint()..color = Colors.white.withOpacity(opacity),
    );
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WinEffectPainter old) =>
      old.t != t || old.effect.id != effect.id;
}
