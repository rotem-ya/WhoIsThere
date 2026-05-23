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
    // Snappy, tactile mechanical opening
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
          // Underlying continuous image slice
          widget.child,
          
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              // Return nothing once fully open to save rendering
              if (_anim.value >= 0.995) return const SizedBox.shrink();

              return RepaintBoundary(
                child: CustomPaint(
                  painter: _AperturePainter(
                    progress: _anim.value,
                    focused: widget.isFocused,
                  ),
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
  final bool focused;

  static const int bladeCount = 8;
  
  // Premium DSLR Palette - Heavy Gunmetal & Black Chrome
  static const Color gunmetalDark = Color(0xFF101012);
  static const Color gunmetalBase = Color(0xFF1C1C1F);
  static const Color gunmetalLight = Color(0xFF2D2D32);
  static const Color chromeHighlight = Color(0xFF5A5A62);

  const _AperturePainter({
    required this.progress,
    required this.focused,
  });

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

    // 1. Setup Layer for masking
    canvas.saveLayer(rect, Paint());

    // 2. Base layer to ensure complete opacity behind blades
    final bgPaint = Paint()..color = gunmetalDark;
    canvas.drawRect(rect, bgPaint);

    // 3. Draw overlapping filled mechanical blades
    final rotation = progress * math.pi * 0.35;
    
    for (int i = 0; i < bladeCount; i++) {
      final angle = (i * 2 * math.pi / bladeCount) + rotation;
      // Extend the blade far into the next sector to create realistic geometric overlap
      final nextAngle = ((i + 1.8) * 2 * math.pi / bladeCount) + rotation; 

      // Points constructing a single aperture blade
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

      // DSLR brushed metal gradient relative to blade angle
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment(math.cos(angle), math.sin(angle)),
          end: Alignment(math.cos(angle + math.pi), math.sin(angle + math.pi)),
          colors: const [gunmetalLight, gunmetalBase, gunmetalDark],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(rect);

      // Deep drop shadow separating this blade from the one beneath it
      canvas.drawShadow(bladePath, Colors.black, 6.0, true);
      
      // Fill the solid metal blade
      canvas.drawPath(bladePath, gradientPaint);

      // Dark seam line
      final seamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black
        ..strokeWidth = 1.5;
      canvas.drawPath(bladePath, seamPaint);
      
      // Inner edge subtle chrome reflection
      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = chromeHighlight.withOpacity(0.4)
        ..strokeWidth = 0.5;
      canvas.drawPath(bladePath, highlightPaint);
    }

    // 4. Cut the expanding iris hole
    final maxRadius = diagonal / 1.1; // Ensure hole grows large enough to clear corners
    final currentRadius = progress * maxRadius;

    if (currentRadius > 0) {
      final irisPath = _createIrisHole(center, currentRadius, rotation);
      final clearPaint = Paint()..blendMode = BlendMode.clear;
      canvas.drawPath(irisPath, clearPaint);
    }

    // 5. Restore layer to finalize mask
    canvas.restore();

    // 6. Draw mechanical rim highlights ON TOP of the cleared hole
    if (currentRadius > 0 && progress < 1.0) {
      final irisPath = _createIrisHole(center, currentRadius, rotation);
      
      // Heavy shadow inside the cutting rim
      final innerRimShadow = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black.withOpacity(0.8)
        ..strokeWidth = 3.0;
      canvas.drawPath(irisPath, innerRimShadow);

      // Sharp metallic edge
      final outerRimHighlight = Paint()
        ..style = PaintingStyle.stroke
        ..color = chromeHighlight
        ..strokeWidth = 1.0;
      canvas.drawPath(irisPath, outerRimHighlight);
    }

    // 7. Focus State (minimalist UI indicator, unobtrusive)
    if (focused) {
      final focusPaint = Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(rect, focusPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AperturePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.focused != focused;
  }
}
