import 'dart:math' as math;

import 'package:flutter/material.dart';

class VaultGemTile extends StatefulWidget {
  final bool isRevealed;
  final bool isFocused;
  final Widget child;

  const VaultGemTile({
    super.key,
    required this.isRevealed,
    required this.child,
    this.isFocused = false,
  });

  @override
  State<VaultGemTile> createState() => _VaultGemTileState();
}

class _VaultGemTileState extends State<VaultGemTile> with SingleTickerProviderStateMixin {
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldDark = Color(0xFFA1811A);
  static const Color _navyBlack = Color(0xFF050A14);
  static const Color _cyan = Color(0xFF87CEEB);

  late final AnimationController _controller;
  late final Animation<double> _aperture;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
      value: widget.isRevealed ? 1.0 : 0.0,
    );
    _aperture = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(covariant VaultGemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      if (widget.isRevealed) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse(from: 1.0);
      }
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
      animation: _aperture,
      builder: (context, _) {
        final progress = _aperture.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isRevealed
                  ? _gold.withOpacity(0.82)
                  : widget.isFocused
                      ? _gold
                      : _gold.withOpacity(0.34),
              width: widget.isFocused && !widget.isRevealed ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.56),
                  blurRadius: 9,
                  offset: const Offset(0, 5)),
              if (widget.isFocused && !widget.isRevealed)
                BoxShadow(color: _gold.withOpacity(0.55), blurRadius: 10, spreadRadius: 1),
              if (widget.isRevealed)
                BoxShadow(color: _cyan.withOpacity(0.22), blurRadius: 14, spreadRadius: 1),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                if (progress < 1.0)
                  CustomPaint(
                    painter: _AperturePlatePainter(
                      // clamp guards against easeOutBack overshoot past 1.0
                      progress: progress.clamp(0.0, 1.0),
                      isFocused: widget.isFocused,
                      gold: _gold,
                      goldDark: _goldDark,
                      navyBlack: _navyBlack,
                    ),
                  ),
                if (progress < 0.96)
                  _LockMark(progress: progress, isFocused: widget.isFocused, gold: _gold),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockMark extends StatelessWidget {
  final double progress;
  final bool isFocused;
  final Color gold;

  const _LockMark({
    required this.progress,
    required this.isFocused,
    required this.gold,
  });

  @override
  Widget build(BuildContext context) {
    // Fade out quickly in the first third of the animation
    final opacity = (1.0 - (progress * 3.0)).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Center(
          child: Icon(
            Icons.lock_outline_rounded,
            color: gold.withOpacity(isFocused ? 0.92 : 0.46),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _AperturePlatePainter extends CustomPainter {
  final double progress;
  final bool isFocused;
  final Color gold;
  final Color goldDark;
  final Color navyBlack;

  const _AperturePlatePainter({
    required this.progress,
    required this.isFocused,
    required this.gold,
    required this.goldDark,
    required this.navyBlack,
  });

  // Build a regular hexagon path at [center] with [radius], rotated by [rotation] radians.
  // This is the aperture "hole" that grows as progress → 1.
  static Path _hexPath(Offset center, double radius, double rotation) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i + rotation;
      final pt = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    // maxRadius large enough to fully cover the tile when the iris is closed (t=0)
    final maxRadius = diag * 0.62;
    final t = progress;
    final rect = Offset.zero & size;

    // Rotation: iris rotates 30° (π/6) as it opens — the "snap" comes from easeOutBack
    final rotAngle = t * math.pi / 6;
    // Aperture opening radius: 0 when fully closed, maxRadius when fully open
    final apertureR = maxRadius * t;

    // ── 1. Dark mechanical plate with hexagonal aperture hole ─────────
    //
    // PathFillType.evenOdd means the overlap between the outer rect and the
    // inner hexagon is "un-filled", revealing the image beneath.
    final platePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(11)));

    if (apertureR > 0.5) {
      platePath.addPath(_hexPath(center, apertureR, rotAngle), Offset.zero);
    }

    // Gradient background — fully opaque, image cannot leak through
    canvas.drawPath(
      platePath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10213A), Color(0xFF050A14), Color(0xFF02050B)],
          stops: [0.0, 0.58, 1.0],
        ).createShader(rect),
    );

    // Radial vignette — depth on the dark plate
    canvas.drawPath(
      platePath,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.7,
          colors: const [Color(0x00000000), Color(0xBB000000)],
          stops: const [0.45, 1.0],
        ).createShader(rect),
    );

    // ── 2. Blade dividers: 6 lines from aperture edge to tile boundary ─
    //
    // Each line runs along a hexagon vertex direction, visually separating
    // the 6 "blade" segments of the dark plate.
    final bladePaint = Paint()
      ..color = (isFocused ? gold : goldDark).withOpacity(isFocused ? 0.55 : 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i + rotAngle;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * (apertureR + 1);
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * maxRadius;
      canvas.drawLine(inner, outer, bladePaint);
    }

    // ── 3. Gold hexagonal iris ring at the aperture edge ──────────────
    if (apertureR > 1) {
      // Soft inner shadow to add depth to the opening
      canvas.drawCircle(
        center,
        apertureR,
        Paint()
          ..color = Colors.black.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Gold hexagonal outline — follows the exact shape of the aperture hole
      canvas.drawPath(
        _hexPath(center, apertureR, rotAngle),
        Paint()
          ..color = gold.withOpacity(0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePlatePainter old) =>
      old.progress != progress || old.isFocused != isFocused;
}
