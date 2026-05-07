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
  static const Color kGold = Color(0xFFD4AF37);
  static const Color kNavy = Color(0xFF07101F);
  
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutQuart,
    );
    
    if (widget.isRevealed) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant VaultGemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRevealed != oldWidget.isRevealed) {
      if (widget.isRevealed) {
        // תיקון: תמיד מתחיל מ-0 כדי להבטיח אנימציה מלאה בכל חשיפה
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
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
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isFocused ? kGold : kGold.withOpacity(0.4),
          width: widget.isFocused ? 2.5 : 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // התמונה המסתתרת תמיד למטה
            widget.child,
            
            // צמצם הלהבים (Aperture)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                if (_animation.value >= 0.99) return const SizedBox.shrink();
                
                return CustomPaint(
                  painter: ApertureIrisPainter(
                    progress: _animation.value,
                  ),
                );
              },
            ),
            
            // המנעול המרכזי
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                double lockOpacity = (1.0 - _animation.value * 4.0).clamp(0.0, 1.0);
                if (lockOpacity <= 0) return const SizedBox.shrink();
                
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kNavy.withOpacity(0.5),
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: kGold,
                      size: 32,
                    ),
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

class ApertureIrisPainter extends CustomPainter {
  final double progress;

  ApertureIrisPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    
    final outerRadius = diagonal * 0.7;
    final openingRadius = progress * outerRadius * 1.2;

    // חסימה מוחלטת ב-progress=0
    canvas.drawRect(rect, Paint()..color = const Color(0xFF07101F));

    const int bladeCount = 8;
    final double angleStep = (2 * math.pi) / bladeCount;
    final double rotation = progress * (math.pi / 4);

    for (int i = 0; i < bladeCount; i++) {
      final double startAngle = i * angleStep + rotation;
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFF7EF8A),
            const Color(0xFFA1811A),
          ],
        ).createShader(rect);

      final path = Path();
      
      // נקודות הלהב הקשתי (Aperture Blade)
      Offset p1 = center + Offset(math.cos(startAngle), math.sin(startAngle)) * openingRadius;
      Offset p2 = center + Offset(math.cos(startAngle + angleStep * 1.5), math.sin(startAngle + angleStep * 1.5)) * outerRadius;
      Offset p3 = center + Offset(math.cos(startAngle + angleStep * 3.0), math.sin(startAngle + angleStep * 3.0)) * outerRadius;

      path.moveTo(p1.dx, p1.dy);
      
      // המתמטיקה של הקימור האורגני
      Offset controlPoint = center + Offset(
        math.cos(startAngle + angleStep * 0.8),
        math.sin(startAngle + angleStep * 0.8),
      ) * (openingRadius + (outerRadius - openingRadius) * 0.3);
      
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.close();

      // צל לעומק תלת-מימדי
      canvas.drawPath(path, Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      canvas.drawPath(path, paint);
      
      // קו מתאר להדגשת המכניקה
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF4A3B10).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(ApertureIrisPainter oldDelegate) => oldDelegate.progress != progress;
}
