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
      duration: const Duration(milliseconds: 230),
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
      decoration: (widget.isFocused && !widget.isRevealed)
          ? BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 0.6,
              ),
            )
          : null,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                if (_anim.value >= 1.0) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _ApertureIrisPainter(progress: _anim.value),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApertureIrisPainter extends CustomPainter {
  final double progress;
  static const int _blades = 8;

  const _ApertureIrisPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;
    final diagonal =
        math.sqrt(size.width * size.width + size.height * size.height);

    final eased = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));

    // Iris opening — 1.8× faster blade rotation for clearly mechanical feel
    final double openFactor;
    if (progress <= 0.82) {
      openFactor = Curves.easeInOutCubic.transform(progress / 0.82);
    } else {
      final t = (progress - 0.82) / 0.18;
      openFactor = 1.0 + math.sin(t * math.pi) * 0.045;
    }
    // Expanded to 0.84 so iris visibly fills entire tile
    final openRadius = openFactor * diagonal * 0.84;
    final rotation = eased * math.pi / _blades * 1.8;

    // ── Compositing layer ─────────────────────────────────────────────────
    canvas.saveLayer(rect, Paint());

    // 1. Glossy near-black DSLR body base
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0A1420));

    // 2. Strong directional metallic sheen — overhead light on polished glass
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.transparent,
            Colors.black.withOpacity(0.28),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );

    // 3. 8 high-contrast aperture blades: dark vs. lighter gunmetal
    for (int i = 0; i < _blades; i++) {
      final a0 = i * 2 * math.pi / _blades + rotation;
      final a1 = (i + 1) * 2 * math.pi / _blades + rotation;
      final aMid = (a0 + a1) / 2;

      final bladePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + diagonal * math.cos(a0),
          center.dy + diagonal * math.sin(a0),
        )
        ..lineTo(
          center.dx + diagonal * math.cos(aMid),
          center.dy + diagonal * math.sin(aMid),
        )
        ..lineTo(
          center.dx + diagonal * math.cos(a1),
          center.dy + diagonal * math.sin(a1),
        )
        ..close();

      canvas.drawPath(
        bladePath,
        Paint()
          ..color =
              i.isEven ? const Color(0xFF1A2D42) : const Color(0xFF060E18),
      );

      // Clearly visible radial dividers — white hairlines at full opacity
      canvas.drawLine(
        center,
        Offset(
          center.dx + diagonal * math.cos(a0),
          center.dy + diagonal * math.sin(a0),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..strokeWidth = 1.0,
      );
    }

    // 4. Center pivot hub — 3-ring metallic stack (visible anchor point)
    canvas.drawCircle(center, 7.0, Paint()..color = const Color(0xFF0A1420));
    canvas.drawCircle(
      center,
      7.0,
      Paint()
        ..color = Colors.white.withOpacity(0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawCircle(center, 4.5, Paint()..color = const Color(0xFF141E2A));
    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFF0A1018));
    canvas.drawCircle(
      center,
      2.5,
      Paint()
        ..color = Colors.white.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // 5. Metallic specular sweep across blades during opening
    if (progress > 0.08 && progress < 0.65) {
      final sweepT = ((progress - 0.08) / 0.57).clamp(0.0, 1.0);
      final sweepAlpha =
          (sweepT < 0.5 ? sweepT * 2 : (1.0 - sweepT) * 2) * 0.12;
      if (sweepAlpha > 0.005) {
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(sweepAlpha),
                Colors.transparent,
              ],
              stops: [
                (sweepT - 0.20).clamp(0.0, 1.0),
                sweepT.clamp(0.0, 1.0),
                (sweepT + 0.20).clamp(0.0, 1.0),
              ],
            ).createShader(rect),
        );
      }
    }

    // 6. Punch iris opening via BlendMode.clear
    if (openRadius > 0.5) {
      canvas.drawPath(
        _irisPolygon(center, openRadius, rotation),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();
    // ── End compositing layer ─────────────────────────────────────────────

    // 7. Bright metallic blade-tip ring at iris edge
    if (openRadius > 1.5 && progress < 0.97) {
      canvas.drawPath(
        _irisPolygon(center, openRadius, rotation),
        Paint()
          ..color = Colors.white.withOpacity(0.45)
          ..strokeWidth = 0.9
          ..style = PaintingStyle.stroke,
      );
    }

    // 8. Center lens exposure glow — visible flash as image is "exposed"
    if (progress > 0.15 && progress < 0.95 && openRadius > 2) {
      final glowProg = ((progress - 0.15) / 0.80).clamp(0.0, 1.0);
      final glowAlpha =
          (glowProg < 0.5 ? glowProg * 2 : (1.0 - glowProg) * 2) * 0.45;
      if (glowAlpha > 0.01) {
        final glowRadius = openRadius * 0.72;
        canvas.drawCircle(
          center,
          glowRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFD0E8F8).withOpacity(glowAlpha),
                Colors.transparent,
              ],
            ).createShader(
                Rect.fromCircle(center: center, radius: glowRadius)),
        );
      }
    }

    // 9. Outer vignette — stronger depth
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.72,
          colors: [Colors.transparent, Colors.black.withOpacity(0.32)],
        ).createShader(rect),
    );
  }

  Path _irisPolygon(Offset center, double radius, double rotation) {
    final path = Path();
    for (int i = 0; i < _blades; i++) {
      final angle = i * 2 * math.pi / _blades + rotation;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _ApertureIrisPainter old) =>
      old.progress != progress;
}
