import 'dart:math' as math;
import 'package:flutter/material.dart';

// במידה ויש לך SoundService, בטל את ה-comment בשורת הנגינה ב-didUpdateWidget
// import 'package:ask_the_kids/services/sound_service.dart'; 

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
      duration: const Duration(milliseconds: 750), // אנימציה יוקרתית ואיטית יותר
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
        // SoundService.playReveal(); // הפעלת הסאונד
        _controller.forward();
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
        boxShadow: [
          if (widget.isFocused)
            BoxShadow(
              color: kGold.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // התמונה המסתתרת
            widget.child,
            
            // הצמצם המכני היוקרתי
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: ApertureIrisPainter(
                    progress: _animation.value,
                  ),
                );
              },
            ),
            
            // המנעול המרכזי שנעלם בפתיחה
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return IgnorePointer(
                  child: Opacity(
                    opacity: (1.0 - _animation.value * 3.5).clamp(0.0, 1.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kNavy.withOpacity(0.6),
                          border: Border.all(color: kGold.withOpacity(0.5), width: 1),
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          color: kGold,
                          size: 26,
                        ),
                      ),
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
    if (progress >= 0.99) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;
    
    // רדיוס חיצוני שחוסם את כל הפינות
    final outerRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.7;
    
    // רדיוס החור המרכזי שגדל עם ה-progress
    final openingRadius = progress * (size.width * 0.6);

    // בסיס אטום לחלוטין - חסימת תמונה ב-100%
    canvas.drawRect(rect, Paint()..color = const Color(0xFF07101F));

    const int bladeCount = 8; // 8 להבים למראה צפוף ויוקרתי
    final double angleStep = (2 * math.pi) / bladeCount;
    
    // סיבוב מכני תוך כדי פתיחה
    final double rotation = progress * (math.pi / 3);

    for (int i = 0; i < bladeCount; i++) {
      final double startAngle = i * angleStep + rotation;
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFD4AF37), // Gold
            const Color(0xFFF7EF8A), // Highlight Shine
            const Color(0xFFA1811A), // Dark Shadow
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(rect);

      final path = Path();
      
      // נקודה 1: על היקף החור הפנימי
      Offset p1 = center + Offset(math.cos(startAngle), math.sin(startAngle)) * openingRadius;
      
      // נקודה 2: נקודה חיצונית רחוקה (בקצה הלהב הבא ליצירת חפיפה)
      Offset p2 = center + Offset(math.cos(startAngle + angleStep * 1.8), math.sin(startAngle + angleStep * 1.8)) * outerRadius;
      
      // נקודה 3: נקודת סגירה חיצונית רחוקה עוד יותר
      Offset p3 = center + Offset(math.cos(startAngle + angleStep * 3.0), math.sin(startAngle + angleStep * 3.0)) * outerRadius;

      path.moveTo(p1.dx, p1.dy);
      
      // יצירת הקימור המכני המעוגל (The Secret Sauce)
      // נקודת בקרה (Control Point) שמושכת את הקו החוצה בצורה קשתית
      Offset controlPoint = center + Offset(
        math.cos(startAngle + angleStep * 0.8),
        math.sin(startAngle + angleStep * 0.8),
      ) * (openingRadius + (outerRadius - openingRadius) * 0.35);
      
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.close();

      // שכבת צל ליצירת עומק תלת-ממדי בין הלהבים
      canvas.drawPath(path, Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      // ציור הלהב המוזהב
      canvas.drawPath(path, paint);
      
      // קו הפרדה דק וכהה להדגשת המכניקה
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF4A3B10).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }
    
    // טבעת פנימית עדינה (נראה כמו הברגה של עדשה)
    if (openingRadius > 2) {
      canvas.drawCircle(
        center, 
        openingRadius, 
        Paint()
          ..color = const Color(0xFFF7EF8A).withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
      );
    }
  }

  @override
  bool shouldRepaint(ApertureIrisPainter oldDelegate) => oldDelegate.progress != progress;
}
