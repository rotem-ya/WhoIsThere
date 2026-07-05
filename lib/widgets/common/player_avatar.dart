import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/avatar_util.dart';
import '../../models/avatar_frame.dart';
import '../../models/avatar_choice.dart';

class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool isCurrentTurn;
  final bool isEliminated;
  // Stable seed for the generated emoji face (defaults to the name).
  final String? seed;
  // Cosmetic frame id (purchased & equipped). Null/'none' → no ring.
  final String? frameId;
  // Chosen avatar id. Null/'auto' → generated face (or photo when present).
  final String? avatarId;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isCurrentTurn = false,
    this.isEliminated = false,
    this.seed,
    this.frameId,
    this.avatarId,
  });

  @override
  Widget build(BuildContext context) {
    final style = avatarFor(seed ?? name);
    final choice = avatarChoiceFor(avatarId);
    // An explicit avatar choice wins over both the generated face and a photo,
    // since the player deliberately picked it.
    final useChoice = !choice.isAuto;

    final Widget face;
    if (useChoice) {
      face = Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: choice.gradient,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glossy top-left highlight for a premium, 3-D feel.
            const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.5, -0.6),
                  radius: 0.9,
                  colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                  stops: [0.0, 0.7],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Text(
              choice.emoji,
              style: TextStyle(fontSize: radius * 1.05, height: 1.0),
            ),
          ],
        ),
      );
    } else {
      face = CircleAvatar(
        radius: radius,
        backgroundColor: photoUrl != null
            ? AppColors.primary.withOpacity(0.2)
            : style.color.withOpacity(0.30),
        backgroundImage:
            photoUrl != null ? CachedNetworkImageProvider(photoUrl!) : null,
        child: photoUrl == null
            ? Text(
                style.emoji,
                style: TextStyle(fontSize: radius * 1.0, height: 1.0),
              )
            : null,
      );
    }

    final Widget core = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isCurrentTurn ? AppColors.primary : Colors.transparent,
          width: 3,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Stack(
        children: [
          face,
          if (isEliminated)
            CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.eliminatedOverlay,
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: radius,
              ),
            ),
        ],
      ),
    );

    final frame = frameFor(frameId);
    if (frame.isNone) return core;
    return _FrameRing(frame: frame, radius: radius, child: core);
  }
}

/// Decorative gradient ring drawn around the avatar for equipped cosmetic frames.
class _FrameRing extends StatelessWidget {
  final AvatarFrame frame;
  final double radius;
  final Widget child;

  const _FrameRing({
    required this.frame,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final ringWidth = (radius * 0.16).clamp(2.5, 6.0);
    final ringColors = frame.colors.length == 1
        ? [frame.colors.first, frame.colors.first]
        : [...frame.colors, frame.colors.first];
    final total = (radius + ringWidth) * 2;

    final base = Container(
      width: total,
      height: total,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: ringColors),
        boxShadow: frame.glow
            ? [
                BoxShadow(
                  color: frame.accent.withOpacity(0.55),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (frame.studs == 0 && !frame.doubleRing) return base;

    return SizedBox(
      width: total,
      height: total,
      child: Stack(
        alignment: Alignment.center,
        children: [
          base,
          Positioned.fill(
            child: CustomPaint(
              painter: _FrameOrnamentPainter(
                colors: frame.colors,
                studs: frame.studs,
                doubleRing: frame.doubleRing,
                ringWidth: ringWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints premium frame ornaments on top of the base gradient ring: a thin
/// inner accent ring and/or evenly-spaced gem studs sitting on the ring.
class _FrameOrnamentPainter extends CustomPainter {
  final List<Color> colors;
  final int studs;
  final bool doubleRing;
  final double ringWidth;

  _FrameOrnamentPainter({
    required this.colors,
    required this.studs,
    required this.doubleRing,
    required this.ringWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    // The gem ring sits centred on the coloured band.
    final bandR = outerR - ringWidth / 2;

    if (doubleRing) {
      final innerR = outerR - ringWidth - 1.2;
      if (innerR > 2) {
        canvas.drawCircle(
          center,
          innerR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (ringWidth * 0.35).clamp(0.8, 2.0)
            ..color = Colors.white.withOpacity(0.75),
        );
      }
    }

    if (studs > 0) {
      final gem = (ringWidth * 0.55).clamp(1.4, 3.6);
      for (var i = 0; i < studs; i++) {
        final a = (i / studs) * math.pi * 2 - math.pi / 2;
        final p = Offset(
            center.dx + math.cos(a) * bandR, center.dy + math.sin(a) * bandR);
        final c = colors.isEmpty
            ? Colors.white
            : colors[i % colors.length];
        // Gem body + white highlight for a faceted look.
        canvas.drawCircle(p, gem, Paint()..color = Colors.white.withOpacity(0.9));
        canvas.drawCircle(p, gem * 0.7, Paint()..color = c);
        canvas.drawCircle(
            Offset(p.dx - gem * 0.25, p.dy - gem * 0.25),
            gem * 0.22,
            Paint()..color = Colors.white.withOpacity(0.9));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FrameOrnamentPainter old) =>
      old.studs != studs ||
      old.doubleRing != doubleRing ||
      old.ringWidth != ringWidth ||
      old.colors != colors;
}
