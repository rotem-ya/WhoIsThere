import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/game_image_model.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_header.dart';

class DiscoveredImagesScreen extends ConsumerWidget {
  final List<String> discoveredImageIds;
  const DiscoveredImagesScreen({super.key, required this.discoveredImageIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allImagesAsync = ref.watch(allImagesProvider);

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          AppHeader(
            title: 'המקומות שגיליתי',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.maybePop(context);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (discoveredImageIds.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌍', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    Text(
                      'עדיין לא גילית מקומות',
                      style: AppTextStyles.titleDark,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'שחק משחק ראשון כדי לגלות מקומות',
                      style: AppTextStyles.subtitleDark,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: allImagesAsync.when(
                data: (allImages) {
                  final discovered = allImages
                      .where((img) => discoveredImageIds.contains(img.id))
                      .toList();
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: discovered.length,
                    itemBuilder: (context, index) {
                      final img = discovered[index];
                      return _DiscoveredImageCard(image: img);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Center(
                  child: Text('שגיאה: $e', style: AppTextStyles.subtitleLight),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoveredImageCard extends StatelessWidget {
  final GameImageModel image;
  const _DiscoveredImageCard({required this.image});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2A4A6A).withOpacity(0.5),
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image.thumbnailUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: image.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xDD07101F), Color(0x0007101F)],
                  ),
                ),
                child: Text(
                  image.name.isNotEmpty ? image.name : image.answer,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1E30),
      child: const Center(
        child: Text('🌍', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}
