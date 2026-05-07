import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
  late final AnimationController _controller;
  late final Animation<double> _animation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuart);
    
    if (widget.isRevealed) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(VaultGemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      if (widget.isRevealed) {
        _audioPlayer.play(AssetSource('sounds/vault_open.mp3')).catchError((e) => print(e));
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isFocused ? const Color(0xFFD4AF37) : const Color(0xFFD4AF37).withOpacity(0.4),
          width: widget.isFocused ? 2.5 : 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                if (_animation.value >= 0.98) return const SizedBox.shrink();
                return CustomPaint(painter: ApertureIrisPainter(progress: _animation.value));
              },
            ),
            // מנעול מרכזי
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return Opacity(
                  opacity: (1.0 - _animation.value * 4).clamp(0.0, 1.0),
                  child: const Center(child: Icon(Icons.lock_person_rounded, color: Color(0xFFD4AF37), size: 28)),
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
    final outerRadius = math.sqrt(size.width * size.width + size.height * size.height) * 0.7;
    final openingRadius = progress * outerRadius * 1.2;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF07101F));

    const int bladeCount = 8;
    final double angleStep = (2 * math.pi) / bladeCount;
    final double rotation = progress * (math.pi / 3);

    for (int i = 0; i < bladeCount; i++) {
      final double startAngle = i * angleStep + rotation;
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFFD4AF37), const Color(0xFFF7EF8A), const Color(0xFFA1811A)],
        ).createShader(Offset.zero & size);

      final path = Path();
      Offset p1 = center + Offset(math.cos(startAngle), math.sin(startAngle)) * openingRadius;
      Offset p2 = center + Offset(math.cos(startAngle + angleStep * 1.8), math.sin(startAngle + angleStep * 1.8)) * outerRadius;
      Offset p3 = center + Offset(math.cos(startAngle + angleStep * 3.0), math.sin(startAngle + angleStep * 3.0)) * outerRadius;

      path.moveTo(p1.dx, p1.dy);
      path.quadraticBezierTo(
        center.dx + math.cos(startAngle + angleStep * 0.8) * outerRadius * 0.4,
        center.dy + math.sin(startAngle + angleStep * 0.8) * outerRadius * 0.4,
        p2.dx, p2.dy,
      );
      path.lineTo(p3.dx, p3.dy);
      path.close();

      canvas.drawPath(path, Paint()..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(ApertureIrisPainter oldDelegate) => oldDelegate.progress != progress;
}
