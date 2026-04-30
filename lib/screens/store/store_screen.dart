import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final imagesAsync = ref.watch(allImagesProvider);

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: 'חנות',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
            trailing: userAsync.when(
              data: (user) => _PointsPill(points: user?.totalPoints ?? 0),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: imagesAsync.when(
              data: (images) {
                final freeImages = images.where((i) => !i.isPremium).toList();
                final premiumImages = images.where((i) => i.isPremium).toList();
                final user = userAsync.value;
                void showComingSoon() {
                  AppFeedback.selection();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('הרמזים יופעלו בשלב הבא')),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            Text('שדרוגים למשחק',
                                style: AppTextStyles.titleDark),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'קנה רמזים וחבילות תמונות כדי להפוך כל סיבוב למעניין יותר.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.subtitleDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('רמזים', style: AppTextStyles.titleLight),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _HintCard(
                              icon: Icons.lightbulb_outline_rounded,
                              title: 'רמז חתיכה',
                              description: 'עזרה קטנה בזמן המשחק',
                              cost: GameConstants.hintCost,
                              canAfford: (user?.totalPoints ?? 0) >=
                                  GameConstants.hintCost,
                              onBuy: showComingSoon,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _HintCard(
                              icon: Icons.category_rounded,
                              title: 'רמז קטגוריה',
                              description: 'דע לאיזה עולם התמונה שייכת',
                              cost: GameConstants.categoryHintCost,
                              canAfford: (user?.totalPoints ?? 0) >=
                                  GameConstants.categoryHintCost,
                              onBuy: showComingSoon,
                            ),
                          ),
                        ],
                      ),
                      if (premiumImages.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('חבילות פרמיום', style: AppTextStyles.titleLight),
                        const SizedBox(height: AppSpacing.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth < 360 ? 1 : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                childAspectRatio: columns == 1 ? 1.35 : 0.78,
                              ),
                              itemCount: premiumImages.length,
                              itemBuilder: (context, index) {
                                final image = premiumImages[index];
                                final owned = user?.purchasedImageIds
                                        .contains(image.id) ??
                                    false;
                                final canAfford =
                                    (user?.totalPoints ?? 0) >= image.cost;
                                return _ImagePackCard(
                                  image: image,
                                  isOwned: owned,
                                  canAfford: canAfford,
                                  onBuy: owned
                                      ? null
                                      : () => _purchaseImage(context, ref,
                                          image, user?.totalPoints ?? 0),
                                );
                              },
                            );
                          },
                        ),
                      ],
                      if (freeImages.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppCard(
                          child: Text(
                            '${freeImages.length} תמונות חינמיות זמינות לכל השחקנים',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(
                  child: Text('שגיאה: $e', style: AppTextStyles.subtitleLight)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseImage(
    BuildContext context,
    WidgetRef ref,
    GameImageModel image,
    int userPoints,
  ) async {
    AppFeedback.success();
    if (userPoints < image.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין מספיק נקודות!')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('אישור רכישה'),
        content: Text('לקנות "${image.name}" תמורת ${image.cost} נקודות?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ביטול'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('קנה'),
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
          content: Text('✅ "${image.name}" נפתח!'),
          backgroundColor: AppColors.accent,
        ),
      );
    }
  }
}

class _PointsPill extends StatelessWidget {
  final int points;

  const _PointsPill({required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('⭐ $points',
          style: AppTextStyles.body.copyWith(color: Colors.white)),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int cost;
  final bool canAfford;
  final VoidCallback onBuy;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.cost,
    required this.canAfford,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subtitleDark),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canAfford ? onBuy : null,
              child: Text('⭐ $cost'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePackCard extends StatelessWidget {
  final GameImageModel image;
  final bool isOwned;
  final bool canAfford;
  final VoidCallback? onBuy;

  const _ImagePackCard({
    required this.image,
    required this.isOwned,
    required this.canAfford,
    this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: CachedNetworkImage(
                imageUrl: image.thumbnailUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppColors.boardBackground),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.boardBackground,
                  child: const Center(
                      child: Icon(Icons.image_rounded, color: Colors.white54)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(image.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isOwned ? null : (canAfford ? onBuy : null),
                    child: Text(isOwned ? 'בבעלותך' : '⭐ ${image.cost}'),
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
