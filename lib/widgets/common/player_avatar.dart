import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';

class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool isCurrentTurn;
  final bool isEliminated;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.isCurrentTurn = false,
    this.isEliminated = false,
  });

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage: photoUrl != null
                ? CachedNetworkImageProvider(photoUrl!)
                : null,
            child: photoUrl == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
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
