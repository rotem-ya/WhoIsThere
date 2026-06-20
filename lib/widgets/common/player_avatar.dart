import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/avatar_util.dart';
import '../../models/avatar_frame.dart';

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

  const PlayerAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isCurrentTurn = false,
    this.isEliminated = false,
    this.seed,
    this.frameId,
  });

  @override
  Widget build(BuildContext context) {
    final style = avatarFor(seed ?? name);
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
          CircleAvatar(
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
          ),
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

    return Container(
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
  }
}
