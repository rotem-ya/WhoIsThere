import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A single shimmering placeholder block. Use these to sketch the shape of
/// content that's still loading (a row, a card, an avatar) so a screen reads as
/// "filling in" rather than "spinning / stuck". Shimmer respects reduce-motion
/// by falling back to a static tint.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.circle = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final base = Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
    if (reduce) return base;
    return base
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1250.ms,
          color: Colors.white.withOpacity(0.14),
        );
  }
}

/// A grid of skeleton tiles, matching the shape of an image / card grid while
/// it loads.
class SkeletonGrid extends StatelessWidget {
  final int count;
  final int columns;
  final double aspectRatio;
  final EdgeInsets padding;

  const SkeletonGrid({
    super.key,
    this.count = 9,
    this.columns = 3,
    this.aspectRatio = 0.82,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: aspectRatio,
      ),
      itemCount: count,
      itemBuilder: (_, __) => const _SkeletonFill(radius: 14),
    );
  }
}

/// A shimmering block that fills whatever cell it's placed in (for grids where
/// the parent dictates the size).
class _SkeletonFill extends StatelessWidget {
  final double radius;
  const _SkeletonFill({this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final base = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const SizedBox.expand(),
    );
    if (reduce) return base;
    return base
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1250.ms, color: Colors.white.withOpacity(0.14));
  }
}

/// A vertical list of skeleton rows (circle avatar + two text lines), matching
/// the shape of the friends / leaderboard / groups lists while they load.
class SkeletonList extends StatelessWidget {
  final int rows;
  final EdgeInsets padding;

  const SkeletonList({
    super.key,
    this.rows = 5,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: rows,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) => Row(
        textDirection: TextDirection.rtl,
        children: [
          const SkeletonBox(height: 44, circle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 120 + (i.isEven ? 40 : 0), height: 13),
                const SizedBox(height: 8),
                const SkeletonBox(width: 80, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 34, height: 18, radius: 9),
        ],
      ),
    );
  }
}
