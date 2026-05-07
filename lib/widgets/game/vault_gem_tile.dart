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

class _VaultGemTileState extends State<VaultGemTile>
    with SingleTickerProviderStateMixin {
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
                offset: const Offset(0, 5),
              ),
              if (widget.isFocused && !widget.isRevealed)
                BoxShadow(
                  color: _gold.withOpacity(0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              if (widget.isRevealed)
                BoxShadow(
                  color: _cyan.withOpacity(0.22),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.child,
                // CustomPaint is always present; painter returns early at progress >= 1.
                // This avoids a flash when easeOutBack briefly overshoots 1.0.
                CustomPaint(
                  painter: _AperturePlatePainter(
                    progress: progress.clamp(0.0, 1.0),
                    isFocused: widget.isFocused,
                    gold: _gold,
                    goldDark: _goldDark,
                    navyBlack: _navyBlack,
                  ),
                ),
                if (progress < 0.96)
                  _LockMark(
                    progress: progress,
                    isFocused: widget.isFocused,
                    gold: _gold,
                  ),
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
    // Fade out in the first third of the animation for a snappy feel
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

  static const int _bladeCount = 6;

  // Each blade spans its "fair share" (2π/N) plus 15% overlap on each side.
  // Total coverage at t=0: 6 × (2π/6 × 1.15) = 2π × 1.15 > 2π → no gaps.
  static const double _halfBlade = math.pi / _bladeCount * 1.15;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final diag = math.sqrt(size.width * size.width + size.height * size.height);

    // outerR extends beyond tile corners; the parent ClipRRect handles cropping.
    final outerR = diag * 0.82;

    // innerR: the iris opening radius.
    // 0 when fully closed (blades meet at tile center), grows to reveal image.
    final maxInnerR = diag * 0.56;
    final innerR = maxInnerR * progress;

    // 45° total rotation as the iris snaps open.
    final rotAngle = progress * math.pi / 4;

    final rect = Offset.zero & size;

    final bladeFill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10213A), Color(0xFF050A14), Color(0xFF02050B)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(rect);

    final bladeEdge = Paint()
      ..color = (isFocused ? gold : goldDark)
          .withOpacity(isFocused ? 0.70 : 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (var i = 0; i < _bladeCount; i++) {
      final centerAngle = (math.pi * 2 / _bladeCount) * i + rotAngle;
      final a0 = centerAngle - _halfBlade; // leading edge angle
      final a1 = centerAngle + _halfBlade; // trailing edge angle
      final sweep = a1 - a0; // always positive

      final path = Path();

      if (innerR < 0.5) {
        // Fully closed: simple sector from tile center to outerR.
        path.moveTo(center.dx, center.dy);
        path.lineTo(
          center.dx + math.cos(a0) * outerR,
          center.dy + math.sin(a0) * outerR,
        );
        path.arcTo(
          Rect.fromCircle(center: center, radius: outerR),
          a0,
          sweep,
          false,
        );
        path.close();
      } else {
        // Opening: annular sector — outer arc (CW) then inner arc (CCW).
        //
        // Path winding (Flutter coords, y-axis down, angles CW):
        //   1. Move to inner leading edge
        //   2. Line out to outer leading edge (radial)
        //   3. Outer arc CW from a0 → a1       (sweep > 0)
        //   4. Line in to inner trailing edge  (radial)
        //   5. Inner arc CCW from a1 → a0      (sweep < 0)
        //   6. close() — no-op, back to step 1
        path.moveTo(
          center.dx + math.cos(a0) * innerR,
          center.dy + math.sin(a0) * innerR,
        );
        path.lineTo(
          center.dx + math.cos(a0) * outerR,
          center.dy + math.sin(a0) * outerR,
        );
        path.arcTo(
          Rect.fromCircle(center: center, radius: outerR),
          a0,
          sweep,
          false,
        );
        path.lineTo(
          center.dx + math.cos(a1) * innerR,
          center.dy + math.sin(a1) * innerR,
        );
        path.arcTo(
          Rect.fromCircle(center: center, radius: innerR),
          a1,
          -sweep,
          false,
        );
        path.close();
      }

      canvas.drawPath(path, bladeFill);
      canvas.drawPath(path, bladeEdge);
    }

    // Gold ring at the iris opening edge — makes the reveal feel premium.
    if (innerR > 1) {
      // Soft shadow behind the ring for depth
      canvas.drawCircle(
        center,
        innerR,
        Paint()
          ..color = Colors.black.withOpacity(0.50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        center,
        innerR,
        Paint()
          ..color = gold.withOpacity(0.90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePlatePainter old) =>
      old.progress != progress || old.isFocused != isFocused;
}
