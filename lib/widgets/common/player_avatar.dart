import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/avatar_util.dart';

class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool isCurrentTurn;
  final bool isEliminated;
  // Stable seed for the generated emoji face (defaults to the name).
  final String? seed;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isCurrentTurn = false,
    this.isEliminated = false,
    this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final style = avatarFor(seed ?? name);
    return Container(
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
  }
}
