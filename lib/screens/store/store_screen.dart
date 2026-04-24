import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../widgets/common/gradient_button.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final imagesAsync = ref.watch(allImagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          userAsync.when(
            data: (user) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '${user?.totalPoints ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: imagesAsync.when(
        data: (images) {
          final freeImages = images.where((i) => !i.isPremium).toList();
          final premiumImages = images.where((i) => i.isPremium).toList();
          final user = userAsync.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hint card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '🛍️ Spend your points!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Unlock premium image packs to make\nyour games more exciting!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

                const SizedBox(height: 24),

                // Game hints section
                const Text(
                  '⚡ In-Game Hints',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkBlue,
                  ),
                ).animate(delay: 100.ms).fadeIn(),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _HintCard(
                        emoji: '🔍',
                        title: 'Piece Hint',
                        description: 'Auto-place one piece',
                        cost: GameConstants.hintCost,
                        canAfford: (user?.totalPoints ?? 0) >=
                            GameConstants.hintCost,
                        onBuy: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HintCard(
                        emoji: '💬',
                        title: 'Category Hint',
                        description: 'Reveal the category',
                        cost: GameConstants.categoryHintCost,
                        canAfford: (user?.totalPoints ?? 0) >=
                            GameConstants.categoryHintCost,
                        onBuy: () {},
                      ),
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(),

                const SizedBox(height: 24),

                if (premiumImages.isNotEmpty) ...[
                  const Text(
                    '🌟 Premium Image Packs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBlue,
                    ),
                  ).animate(delay: 300.ms).fadeIn(),

                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: premiumImages.length,
                    itemBuilder: (context, i) {
                      final img = premiumImages[i];
                      final owned = user?.purchasedImageIds.contains(img.id) ?? false;
                      final canAfford = (user?.totalPoints ?? 0) >= img.cost;

                      return _ImageStoreCard(
                        image: img,
                        isOwned: owned,
                        canAfford: canAfford,
                        onBuy: owned
                            ? null
                            : () => _purchaseImage(
                                context, ref, img, user?.totalPoints ?? 0),
                      )
                          .animate(delay: (i * 100 + 400).ms)
                          .fadeIn()
                          .scale(curve: Curves.elasticOut);
                    },
                  ),
                ],

                if (freeImages.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    '🆓 Free Images',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBlue,
                    ),
                  ).animate(delay: 300.ms).fadeIn(),
                  const SizedBox(height: 8),
                  Text(
                    '${freeImages.length} images available for everyone',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate(delay: 350.ms).fadeIn(),
                ],
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _purchaseImage(
    BuildContext context,
    WidgetRef ref,
    GameImageModel image,
    int userPoints,
  ) async {
    if (userPoints < image.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough points!')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Purchase'),
        content: Text(
            'Buy "${image.name}" for ${image.cost} points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buy'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    await ref.read(authServiceProvider).updateTotalPoints(user.id, -image.cost);
    await ref.read(authServiceProvider).purchaseItem(user.id, image.id, true);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${image.name}" unlocked!'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }
}

class _HintCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final int cost;
  final bool canAfford;
  final VoidCallback onBuy;

  const _HintCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.cost,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.darkBlue,
              fontSize: 14,
            ),
          ),
          Text(
            description,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canAfford ? onBuy : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                '⭐ $cost',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageStoreCard extends StatelessWidget {
  final GameImageModel image;
  final bool isOwned;
  final bool canAfford;
  final VoidCallback? onBuy;

  const _ImageStoreCard({
    required this.image,
    required this.isOwned,
    required this.canAfford,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: CachedNetworkImage(
                imageUrl: image.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.boardBackground),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.boardBackground,
                  child: const Center(
                    child: Icon(Icons.image_rounded,
                        color: AppColors.pieceSlotEmpty, size: 40),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  image.category.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  image.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isOwned ? null : (canAfford ? onBuy : null),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOwned
                          ? AppColors.accent
                          : canAfford
                              ? AppColors.primary
                              : Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      isOwned ? '✅ Owned' : '⭐ ${image.cost}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
