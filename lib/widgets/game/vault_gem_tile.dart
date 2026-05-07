import 'dart:math' as math;
import 'package:flutter/material.dart';

// הערה: במידה ויש לך SoundService, בטל את ה-comment בשורת הנגינה ב-didUpdateWidget
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
      duration: const Duration(milliseconds: 700), // אנימציה חלקה ויוקרתית
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
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
        // SoundService.playReveal(); // הפעלת הסאונד ברגע הלחיצה
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
            // התמונה המסתתרת (Child)
            widget.child,
            
            // הצמצם המכני (Aperture)
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
            
            // מנעול מרכזי שנעלם בפתיחה
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return IgnorePointer(
                  child: Opacity(
                    opacity: (1.0 - _animation.value * 3).clamp(0.0, 1.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kNavy.withOpacity(0.5),
                          border: Border.all(color: kGold.withOpacity(0.5), width: 1),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: kGold,
                          size: 24,
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
    if (progress >= 0.99) return; // אופטימיזציה: אל תצייר אם הכל פתוח

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Offset.zero & size;
    
    // רדיוס חיצוני שחוסם את כל הריבוע (משפט פיתגורס למציאת הפינה)
    final outerRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.6;
    
    // רדיוס הפתיחה - ככל שה-progress גדל, החור המרכזי גדל
    final openingRadius = progress * outerRadius * 1.1;

    // רקע אטום ב-100% כדי ששום פיקסל מהתמונה לא יזלוג
    canvas.drawRect(rect, Paint()..color = const Color(0xFF07101F));

    const int bladeCount = 8; // 8 להבים יוצרים חפיפה עגולה ויוקרתית יותר מ-6
    final double angleStep = (2 * math.pi) / bladeCount;
    
    // סיבוב של הצמצם תוך כדי פתיחה (אפקט מכני קלאסי)
    final double rotation = progress * (math.pi / 4);

    for (int i = 0; i < bladeCount; i++) {
      final double startAngle = i * angleStep + rotation;
      
      final paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4AF37), // Gold
            Color(0xFFF7EF8A), // Highlight
            Color(0xFFA1811A), // Shadow Gold
          ],
        ).createShader(rect);

      final path = Path();
      
      // נקודה 1: על היקף החור הפנימי
      Offset p1 = center + Offset(math.cos(startAngle), math.sin(startAngle)) * openingRadius;
      
      // נקודה 2: נקודת העיגון החיצונית
      Offset p2 = center + Offset(math.cos(startAngle), math.sin(startAngle)) * outerRadius;
      
      // נקודה 3: נקודת העיגון החיצונית הבאה (ליצירת רוחב ללהב)
      Offset p3 = center + Offset(math.cos(startAngle + angleStep * 1.5), math.sin(startAngle + angleStep * 1.5)) * outerRadius;

      path.moveTo(p1.dx, p1.dy);
      
      // יצירת הקימור (Curve) של הלהב - זה הסוד למראה המעוגל
      // אנחנו מושכים את הקו בעזרת Control Point שנמצאת ברדיוס ביניים
      Offset controlPoint = center + Offset(
        math.cos(startAngle + angleStep * 0.7),
        math.sin(startAngle + angleStep * 0.7),
      ) * (openingRadius + (outerRadius - openingRadius) * 0.2);
      
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, p3.dx, p3.dy);
      path.lineTo(p2.dx, p2.dy);
      path.close();

      // ציור צל מתחת לכל להב כדי לתת עומק (תלת-מימד)
      canvas.drawPath(path, Paint()
        ..color = Colors.black.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

      // ציור הלהב עצמו
      canvas.drawPath(path, paint);
      
      // קו מתאר דק (Stroke) להדגשת החפיפה המכנית
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF5C4A14).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }
    
    // טבעת פנימית מוזהבת דקה מסביב לחור שנפתח (נראה כמו עדשה)
    if (openingRadius > 2) {
      canvas.drawCircle(
        center, 
        openingRadius, 
        Paint()
          ..color = const Color(0xFFF7EF8A).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
      );
    }
  }

  @override
  bool shouldRepaint(ApertureIrisPainter oldDelegate) => oldDelegate.progress != progress;
}
