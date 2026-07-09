import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/avatar_util.dart';
import '../../models/avatar_choice.dart';

class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool isCurrentTurn;
  final bool isEliminated;
  // Stable seed for the generated emoji face (defaults to the name).
  final String? seed;
  // Deprecated: avatar frames were removed from the store. Accepted (and
  // ignored) so existing call sites keep compiling.
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

    // Avatar frames were removed from the store — no decorative ring.
    return core;
  }
}
