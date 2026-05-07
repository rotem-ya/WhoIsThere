import 'dart:math' as math;
import 'package:flutter/material.dart';
// וודא שהנתיב ל-SoundManager/SoundService שלך נכון כאן
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
      duration: const Duration(milliseconds: 600), // אנימציה מעט איטית יותר בשביל היוקרה
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
        // הזרקת סאונד - וודא שהפונקציה קיימת אצלך
        // SoundService.playReveal(); 
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
          color: widget.isFocused ? kGold : kGold.withOpacity(0.3),
          width: widget.isFocused ? 2.5 : 1.0,
        ),
        boxShadow: [
          if (widget.isFocused)
            BoxShadow(color: kGold.withOpacity(0.4), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // התמונה המסתתרת תמיד למטה
            widget.child,
            
            // המכסה המכני
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: ApertureIrisPainter(
                    progress: _animation.value,
                    isFocused: widget.isFocused,
                  ),
                );
              },
            ),
            
            // המנעול שמופיע רק כשהצמצם סגור כמעט לגמרי
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return Opacity(
                  opacity: (1.0 - _animation.value * 2).clamp(0.0, 1.0),
                  child: Center(
                    child: Icon(
                      Icons.lock_person_rounded,
                      color: kGold.withOpacity(0.9),
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
  final bool isFocused;

  ApertureIrisPainter({required this.progress, required this.isFocused});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height) * 0.6;
    
    // ציור רקע אטום ב-100% מתחת ללהבים למקרה של חריצים קטנים
    final backgroundPaint = Paint()..color = const Color(0xFF07101F);
    if (progress < 1.0) {
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    final bladeCount = 6;
    final double angleStep = (2 * math.pi) / bladeCount;
    
    // חישוב הסיבוב והפתיחה
    final rotation = progress * math.pi / 3; // סיבוב של 60 מעלות
    final expansion = progress * radius * 1.5;

    for (int i = 0; i < bladeCount; i++) {
      final double currentAngle = i * angleStep + rotation;
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFD4AF37), // Gold
            Color(0xFF8A6E2F), // Dark Gold
            Color(0xFFCFB53B), // Shiny Gold
          ],
        ).createShader(Offset.zero & size);

      final path = Path();
      
      // נקודות הלהב - חישוב גיאומטרי של להב כספת
      Offset p1 = center + Offset(math.cos(currentAngle), math.sin(currentAngle)) * expansion;
      Offset p2 = center + Offset(math.cos(currentAngle + angleStep * 1.5), math.sin(currentAngle + angleStep * 1.5)) * radius;
      Offset p3 = center + Offset(math.cos(currentAngle + angleStep * 2), math.sin(currentAngle + angleStep * 2)) * radius;
      
      path.moveTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
      path.close();

      // הוספת צל להפרדה בין הלהבים
      canvas.drawPath(path, Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        
      canvas.drawPath(path, paint);
      
      // קו מתאר דק לכל להב להדגשת המכניקה
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF4A3B10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0);
    }
  }

  @override
  bool shouldRepaint(ApertureIrisPainter oldDelegate) => oldDelegate.progress != progress;
}
