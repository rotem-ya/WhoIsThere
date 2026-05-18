import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

/// Standalone animated vault-puzzle logo mark.
/// Drop it anywhere — no scaffold dependency.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final tileSize = size / 3.6;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withOpacity(0.36),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.92, end: 1.08, duration: 1800.ms),
          Transform.rotate(
            angle: -0.08,
            child: Container(
              width: size * 0.76,
              height: size * 0.76,
              padding: EdgeInsets.all(size * 0.09),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(size * 0.23),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.42),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: List.generate(9, (index) {
                  final isOpen = index == 1 || index == 4 || index == 7;
                  return Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: isOpen
                          ? Colors.white.withOpacity(0.88)
                          : Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                      ),
                    ),
                    child: isOpen
                        ? const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.secondary,
                            size: 18,
                          )
                        : null,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
