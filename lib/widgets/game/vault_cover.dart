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
      duration: const Duration(milliseconds: 210),
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
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: (widget.isFocused && !widget.isRevealed)
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.05),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
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

    // Eased progress — mechanical precision feel
    final eased = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));

    // Iris opening grows from center until it clears the entire tile
    final openRadius = eased * diagonal * 0.76;

    // Blades rotate one blade-step as iris opens
    final rotation = eased * math.pi / _blades;

    // ── Compositing layer: graphite blades + iris hole ─────────────
    canvas.saveLayer(rect, Paint());

    // 1. Base graphite fill
    canvas.drawRect(rect, Paint()..color = const Color(0xFF263848));

    // 2. Directional metallic sheen (single overhead light source)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.09),
            Colors.transparent,
            Colors.black.withOpacity(0.10),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // 3. 8 aperture blade segments — alternating tones for visible iris identity
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

      // Even blades: lighter gunmetal. Odd blades: deeper graphite.
      canvas.drawPath(
        bladePath,
        Paint()
          ..color =
              i.isEven ? const Color(0xFF2E4258) : const Color(0xFF1E3040),
      );

      // Hairline radial divider at each blade edge
      canvas.drawLine(
        center,
        Offset(
          center.dx + diagonal * math.cos(a0),
          center.dy + diagonal * math.sin(a0),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..strokeWidth = 0.4,
      );
    }

    // 4. Center pivot pin (aperture hub)
    canvas.drawCircle(center, 3.0, Paint()..color = const Color(0xFF141E28));
    canvas.drawCircle(
      center,
      3.0,
      Paint()
        ..color = Colors.white.withOpacity(0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    // 5. Punch growing iris hole — image shows through via BlendMode.clear
    if (openRadius > 0.5) {
      canvas.drawPath(
        _irisPolygon(center, openRadius, rotation),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();
    // ── End compositing layer ───────────────────────────────────────

    // 6. Metallic blade-tip highlights at the iris edge (visible during open)
    if (openRadius > 1.5 && progress < 0.97) {
      canvas.drawPath(
        _irisPolygon(center, openRadius, rotation),
        Paint()
          ..color = Colors.white.withOpacity(0.38)
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke,
      );
    }

    // 7. Subtle outer vignette for panel depth
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.78,
          colors: [Colors.transparent, Colors.black.withOpacity(0.18)],
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
