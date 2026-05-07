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
      duration: const Duration(milliseconds: 450),
      value: widget.isRevealed ? 1.0 : 0.0,
    );
    _aperture = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
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
              BoxShadow(color: Colors.black.withOpacity(0.56), blurRadius: 9, offset: const Offset(0, 5)),
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
                  Transform.rotate(
                    angle: progress * math.pi / 6,
                    child: CustomPaint(
                      painter: _AperturePlatePainter(
                        progress: progress,
                        isFocused: widget.isFocused,
                        gold: _gold,
                        goldDark: _goldDark,
                        navyBlack: _navyBlack,
                      ),
                    ),
                  ),
                if (progress < 0.96) _LockMark(progress: progress, isFocused: widget.isFocused, gold: _gold),
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
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.72;
    final radius = maxRadius * progress;
    final rect = Offset.zero & size;

    final platePath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(11)));
    if (radius > 0.01) {
      platePath.addOval(Rect.fromCircle(center: center, radius: radius));
    }

    // Fully opaque mechanical plate. The hidden image must not leak through the closed tile.
    final platePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF10213A),
          Color(0xFF050A14),
          Color(0xFF02050B),
        ],
        stops: [0.0, 0.58, 1.0],
      ).createShader(rect);
    canvas.drawPath(platePath, platePaint);

    final vignettePaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x00000000),
          Color(0xCC000000),
        ],
        stops: [0.46, 1.0],
      ).createShader(rect);
    canvas.drawPath(platePath, vignettePaint);

    final bladePaint = Paint()
      ..color = (isFocused ? gold : goldDark).withOpacity(isFocused ? 0.50 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    for (var i = 0; i < 6; i++) {
      final angle = (math.pi * 2 / 6) * i + (progress * math.pi / 8);
      final from = center + Offset(math.cos(angle), math.sin(angle)) * (radius + 2);
      final to = center + Offset(math.cos(angle), math.sin(angle)) * maxRadius;
      canvas.drawLine(from, to, bladePaint);
    }

    if (radius > 1) {
      final innerShadow = Paint()
        ..color = Colors.black.withOpacity(0.42 * (1.0 - progress * 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(center, radius, innerShadow);

      final goldRing = Paint()
        ..color = gold.withOpacity(0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, goldRing);
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePlatePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isFocused != isFocused;
  }
}
