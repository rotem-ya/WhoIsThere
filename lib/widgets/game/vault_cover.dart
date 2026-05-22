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
      duration: const Duration(milliseconds: 420),
    );

    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutExpo,
    );

    if (widget.isRevealed) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant VaultCover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRevealed && !oldWidget.isRevealed) {
      _ctrl.forward(from: 0.0);
    }

    if (!widget.isRevealed && oldWidget.isRevealed) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,

            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                if (_anim.value >= 0.995) {
                  return const SizedBox.shrink();
                }

                return CustomPaint(
                  painter: _AperturePainter(
                    progress: _anim.value,
                    focused: widget.isFocused,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  final double progress;
  final bool focused;

  static const int bladeCount = 8;

  const _AperturePainter({
    required this.progress,
    required this.focused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final diagonal = math.sqrt(
      size.width * size.width +
          size.height * size.height,
    );

    final eased =
        Curves.easeOutCubic.transform(progress);

    final overshoot =
        math.sin(progress * math.pi) * 0.10;

    final openRadius =
        (eased + overshoot) *
            diagonal *
            0.92;

    final rotation =
        eased *
            math.pi /
            bladeCount *
            3.2;

    canvas.saveLayer(rect, Paint());

    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF03070D),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4E84AA)
                .withOpacity(0.45),
            const Color(0xFF163049)
                .withOpacity(0.20),
            Colors.black.withOpacity(0.72),
          ],
        ).createShader(rect),
    );


    final scanPaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 0.45;

    for (double y = 1; y < size.height; y += 2.5) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        scanPaint,
      );
    }

    for (int i = 0; i < bladeCount; i++) {
      final a0 =
          i * 2 * math.pi / bladeCount + rotation;

      final a1 =
          (i + 1) *
                  2 *
                  math.pi /
                  bladeCount +
              rotation;

      final aMid = (a0 + a1) / 2;

      final blade = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx +
              diagonal * math.cos(a0),
          center.dy +
              diagonal * math.sin(a0),
        )
        ..lineTo(
          center.dx +
              diagonal *
                  1.15 *
                  math.cos(aMid),
          center.dy +
              diagonal *
                  1.15 *
                  math.sin(aMid),
        )
        ..lineTo(
          center.dx +
              diagonal * math.cos(a1),
          center.dy +
              diagonal * math.sin(a1),
        )
        ..close();

      canvas.drawPath(
        blade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: i.isEven
                ? const [
                    Color(0xFF35698D),
                    Color(0xFF122A40),
                    Color(0xFF050C14),
                  ]
                : const [
                    Color(0xFF132D45),
                    Color(0xFF07111B),
                    Color(0xFF010409),
                  ],
          ).createShader(rect),
      );

      canvas.drawLine(
        center,
        Offset(
          center.dx +
              diagonal * math.cos(a0),
          center.dy +
              diagonal * math.sin(a0),
        ),
        Paint()
          ..color = const Color(0xFFA8E8FF)
              .withOpacity(0.28)
          ..strokeWidth = 1.0,
      );
    }

    final hubRadius =
        size.shortestSide * 0.09;

    canvas.drawCircle(
      center,
      hubRadius * 1.8,
      Paint()
        ..color =
            Colors.black.withOpacity(0.55),
    );

    canvas.drawCircle(
      center,
      hubRadius * 1.4,
      Paint()
        ..color = const Color(0xFF16344D),
    );

    canvas.drawCircle(
      center,
      hubRadius * 1.4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFA8E8FF)
            .withOpacity(0.35),
    );

    canvas.drawCircle(
      center,
      hubRadius * 0.75,
      Paint()
        ..color = const Color(0xFF03070D),
    );


    final sweep = math.sin(progress * math.pi).clamp(0.0, 1.0);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.22 * sweep),
            const Color(0xFF80D8FF).withOpacity(0.16 * sweep),
            Colors.transparent,
          ],
          stops: const [0.0, 0.34, 0.48, 1.0],
        ).createShader(rect),
    );

    if (openRadius > 1) {
      canvas.drawPath(
        _irisHole(center, openRadius, rotation),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();

    if (openRadius > 2 && progress < 0.96) {
      canvas.drawPath(
        _irisHole(center, openRadius, rotation),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.45
          ..color = const Color(0xFFA8E8FF)
              .withOpacity(0.72 * (1.0 - progress * 0.35)),
      );
    }

    if (progress > 0.08 && progress < 0.90) {
      final flash =
          math.sin(((progress - 0.08) / 0.82).clamp(0.0, 1.0) * math.pi);

      final flashRadius =
          math.max(4.0, openRadius * 0.72);

      canvas.drawCircle(
        center,
        flashRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withOpacity(0.36 * flash),
              const Color(0xFF8FE7FF).withOpacity(0.34 * flash),
              Colors.transparent,
            ],
            stops: const [0.0, 0.36, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: center,
              radius: flashRadius,
            ),
          ),
      );
    }
  }

  Path _irisHole(
    Offset center,
    double radius,
    double rotation,
  ) {
    const sides = 8;
    final path = Path();

    for (int i = 0; i < sides; i++) {
      final angle =
          i * 2 * math.pi / sides + rotation;

      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(
    covariant _AperturePainter oldDelegate,
  ) {
    return oldDelegate.progress != progress ||
        oldDelegate.focused != focused;
  }
}
