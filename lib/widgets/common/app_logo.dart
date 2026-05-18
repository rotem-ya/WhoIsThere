import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

/// Animated vault-puzzle logo mark.
/// [animated] enables floating + breathing halo + tile shine.
/// [intensity] scales glow opacity (0.0–1.0).
class AppLogo extends StatelessWidget {
  final double size;
  final bool animated;
  final double intensity;

  const AppLogo({
    super.key,
    this.size = 120,
    this.animated = true,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final tileSize = size / 3.6;

    final halo = SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.accent.withOpacity(0.34 * intensity),
              AppColors.primary.withOpacity(0.08 * intensity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );

    final tileGrid = Container(
      width: size * 0.76,
      height: size * 0.76,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.23),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.42 * intensity),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.primary.withOpacity(0.16 * intensity),
            blurRadius: 56,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Stack(
        children: [
          Wrap(
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
                  border:
                      Border.all(color: Colors.white.withOpacity(0.20)),
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
          if (animated)
            Positioned.fill(
              child: IgnorePointer(child: _TileShine()),
            ),
        ],
      ),
    );

    final mark = Transform.rotate(angle: -0.08, child: tileGrid);

    Widget logo = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (animated)
            halo
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 0.88,
                  end: 1.12,
                  duration: 2400.ms,
                  curve: Curves.easeInOut,
                )
          else
            halo,
          mark,
        ],
      ),
    );

    if (!animated) return logo;

    return logo
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: -3.5, end: 3.5, duration: 3200.ms, curve: Curves.easeInOut);
  }
}

// ── Diagonal shine sweep across the tile grid ─────────────────────────────

class _TileShine extends StatelessWidget {
  const _TileShine();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.38,
        heightFactor: 1.2,
        child: Transform.rotate(
          angle: -0.30,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(0.22),
                  Colors.white.withOpacity(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .slideX(begin: -1.6, end: 2.4, duration: 2800.ms, delay: 2500.ms);
  }
}
