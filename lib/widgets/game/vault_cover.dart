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

class _VaultCoverState extends State<VaultCover> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    if (widget.isRevealed) {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant VaultCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _ctrl.forward();
    } else if (!widget.isRevealed && oldWidget.isRevealed) {
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              if (_anim.value >= 0.995) return const SizedBox.shrink();
              return RepaintBoundary(
                child: CustomPaint(
                  painter: _AperturePainter(progress: _anim.value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  final double progress;

  static const int bladeCount = 8;

  static const Color gunmetalDark = Color(0xFF101012);
  static const Color gunmetalBase = Color(0xFF1C1C1F);
  static const Color gunmetalLight = Color(0xFF2D2D32);
  static const Color chromeHighlight = Color(0xFF5A5A62);

  const _AperturePainter({required this.progress});

  Path _createIrisHole(Offset center, double radius, double rotation) {
    final path = Path();
    for (int i = 0; i < bladeCount; i++) {
      final angle = rotation + (i * 2 * math.pi / bladeCount);
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
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    canvas.saveLayer(rect, Paint());

    canvas.drawRect(rect, Paint()..color = gunmetalDark);

    final rotation = progress * math.pi * 0.35;

    for (int i = 0; i < bladeCount; i++) {
      final angle = (i * 2 * math.pi / bladeCount) + rotation;
      final nextAngle = ((i + 1.8) * 2 * math.pi / bladeCount) + rotation;

      final pOuter1 = Offset(
        center.dx + diagonal * math.cos(angle - 0.2),
        center.dy + diagonal * math.sin(angle - 0.2),
      );
      final pOuter2 = Offset(
        center.dx + diagonal * math.cos(nextAngle),
        center.dy + diagonal * math.sin(nextAngle),
      );

      final bladePath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(pOuter1.dx, pOuter1.dy)
        ..lineTo(pOuter2.dx, pOuter2.dy)
        ..close();

      canvas.drawPath(
        bladePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(math.cos(angle), math.sin(angle)),
            end: Alignment(math.cos(angle + math.pi), math.sin(angle + math.pi)),
            colors: const [gunmetalLight, gunmetalBase, gunmetalDark],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(rect),
      );

      // Subtle dark-grey seam — no black, no drawShadow
      canvas.drawPath(
        bladePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = const Color(0xFF1A2530).withOpacity(0.40)
          ..strokeWidth = 0.45,
      );

      canvas.drawPath(
        bladePath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = chromeHighlight.withOpacity(0.4)
          ..strokeWidth = 0.5,
      );
    }

    final maxRadius = diagonal / 1.1;
    final currentRadius = progress * maxRadius;

    if (currentRadius > 0) {
      canvas.drawPath(
        _createIrisHole(center, currentRadius, rotation),
        Paint()..blendMode = BlendMode.clear,
      );
    }

    canvas.restore();

    // Slim chrome rim at iris edge — no heavy black shadow ring
    if (currentRadius > 0 && progress < 1.0) {
      canvas.drawPath(
        _createIrisHole(center, currentRadius, rotation),
        Paint()
          ..style = PaintingStyle.stroke
          ..color = chromeHighlight.withOpacity(0.55)
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
