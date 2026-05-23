import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/economy_config.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/game_image_model.dart';
import '../../providers/providers.dart';
import '../../services/hint_economy_guard.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/pressable_scale.dart';
import '../../widgets/economy/coin_display.dart';

class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imagesAsync = ref.watch(allImagesProvider);
    final walletAsync = ref.watch(walletProvider);
    final coins = walletAsync.valueOrNull?.coins ?? 0;

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
            trailing: const CoinDisplay(compact: true),
          ),
          Expanded(
            child: imagesAsync.when(
              data: (images) {
                final freeImages =
                    images.where((i) => !i.isPremium).toList();
                final premiumImages =
                    images.where((i) => i.isPremium).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Starter Pack ──────────────────────────────────
                      _StarterPackCard(coins: coins),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Card skins ────────────────────────────────────
                      _CardSkinsSection(),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Rewarded ad ───────────────────────────────────
                      _RewardedAdTile(ref: ref),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Hint packs ────────────────────────────────────
                      Text('רמזים', style: AppTextStyles.titleLight),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _HintCard(
                              icon: Icons.lightbulb_outline_rounded,
                              title: 'חשוף משבצת',
                              description: 'חשוף אזור נסתר בתמונה',
                              price: EconomyConfig.hintRevealTilePrice,
                              coins: coins,
                              onBuy: () => _buyHint(
                                  context, ref, HintType.revealTile, coins),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _HintCard(
                              icon: Icons.casino_outlined,
                              title: 'ניחוש נוסף',
                              description: 'הזדמנות ניחוש נוספת',
                              price: EconomyConfig.hintExtraGuessPrice,
                              coins: coins,
                              onBuy: () => _buyHint(
                                  context, ref, HintType.extraGuess, coins),
                            ),
                          ),
                        ],
                      ),

                      // ── Premium images ────────────────────────────────
                      if (premiumImages.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('חבילות פרמיום',
                            style: AppTextStyles.titleLight),
                        const SizedBox(height: AppSpacing.sm),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns =
                                constraints.maxWidth < 360 ? 1 : 2;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.md,
                                childAspectRatio:
                                    columns == 1 ? 1.65 : 1.05,
                              ),
                              itemCount: premiumImages.length,
                              itemBuilder: (context, index) {
                                final image = premiumImages[index];
                                return _ImagePackCard(image: image);
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
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 320.ms, curve: Curves.easeOut);
              },
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.accent)),
              error: (e, _) => Center(
                  child: Text('שגיאה: $e',
                      style: AppTextStyles.subtitleLight)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _buyHint(
    BuildContext context,
    WidgetRef ref,
    HintType hint,
    int currentCoins,
  ) async {
    AppFeedback.selection();
    final guard = ref.read(hintEconomyGuardProvider);
    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) return;

    if (!guard.canAfford(wallet, hint)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אין מספיק מטבעות!')),
      );
      return;
    }

    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    final granted =
        await guard.useHint(uid: uid, hint: hint, wallet: wallet);
    if (!context.mounted) return;

    if (granted) {
      AppFeedback.success();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ הרמז נקנה ויוחל במשחק הבא')),
      );
    }
  }
}

// ── Starter Pack ──────────────────────────────────────────────────────────────

class _StarterPackCard extends StatelessWidget {
  final int coins;
  const _StarterPackCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1060), Color(0xFF0D0730)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.14),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔥 הצעה מיוחדת',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Starter Pack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          _PackFeature(text: '500 🪙 מטבעות'),
          _PackFeature(text: 'כל תמונות הפרמיום לחודש'),
          _PackFeature(text: 'הסרת פרסומות'),
          const SizedBox(height: 16),
          PressableScale(
            onTap: () {},
            child: SizedBox(
              width: double.infinity,
              child: AbsorbPointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: const Color(0xFF07101F),
                      textStyle: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('רכישה — 9.99₪'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackFeature extends StatelessWidget {
  final String text;
  const _PackFeature({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFFD4AF37), size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rewarded Ad ───────────────────────────────────────────────────────────────

class _RewardedAdTile extends ConsumerWidget {
  final WidgetRef ref;
  const _RewardedAdTile({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider).valueOrNull;
    final adsToday = wallet?.adRewardsTodayCount ?? 0;
    final remaining = (EconomyConfig.maxAdRewardsPerDay - adsToday)
        .clamp(0, EconomyConfig.maxAdRewardsPerDay);
    final canWatch = remaining > 0;

    return GestureDetector(
      onTap: canWatch ? () => _watchAd(context, ref) : null,
      child: AnimatedOpacity(
        opacity: canWatch ? 1.0 : 0.48,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF07101F).withOpacity(0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: const Color(0xFF87CEEB).withOpacity(0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF87CEEB).withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF87CEEB).withOpacity(0.30)),
                ),
                child: const Icon(Icons.play_circle_outline_rounded,
                    color: Color(0xFF87CEEB), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'צפה וקבל ${EconomyConfig.adRewardCoins} 🪙',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      canWatch
                          ? 'נותרו $remaining/${ EconomyConfig.maxAdRewardsPerDay} צפיות היום'
                          : 'המכסה היומית הושלמה',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.52),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white38, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _watchAd(BuildContext context, WidgetRef ref) async {
    AppFeedback.selection();
    final uid = ref.read(firebaseUserProvider).valueOrNull?.uid;
    if (uid == null) return;

    // In production: show real rewarded ad here first.
    // For MVP we grant the reward directly.
    final granted =
        await ref.read(economyServiceProvider).applyAdReward(uid);
    if (!context.mounted) return;

    if (granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '+${EconomyConfig.adRewardCoins} מטבעות הופקדו! 🪙'),
          backgroundColor: const Color(0xFF0A3880),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('המכסה היומית הושלמה')),
      );
    }
  }
}

// ── Hint card ─────────────────────────────────────────────────────────────────

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int price;
  final int coins;
  final VoidCallback onBuy;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.price,
    required this.coins,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = coins >= price;
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
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subtitleDark),
          const SizedBox(height: AppSpacing.md),
          PressableScale(
            onTap: canAfford ? onBuy : null,
            child: SizedBox(
              width: double.infinity,
              child: AbsorbPointer(
                child: ElevatedButton(
                  onPressed: canAfford ? onBuy : null,
                  child: Text('🪙 $price'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image pack card ───────────────────────────────────────────────────────────

class _ImagePackCard extends StatelessWidget {
  final GameImageModel image;

  const _ImagePackCard({required this.image});

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
                      child: Icon(Icons.image_rounded,
                          color: Colors.white54)),
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
                    onPressed: null, // IAP integration — Stage 6
                    child: Text('🪙 ${image.cost}'),
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

// ── Card Skins section (banner that navigates to /store/skins) ───────────────

class _CardSkinsSection extends StatelessWidget {
  const _CardSkinsSection();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/store/skins'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1A2E), Color(0xFF1A0A2E)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF8B6FFF).withOpacity(0.55),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8B6FFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF8B6FFF).withOpacity(0.40),
                ),
              ),
              child: const Icon(Icons.style_rounded,
                  color: Color(0xFF8B6FFF), size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('עיצובי קלפים',
                      style: AppTextStyles.titleLight
                          .copyWith(fontSize: 16)),
                  const SizedBox(height: 2),
                  const Text(
                    'בחר עיצוב לכרטיסיות המשחק',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }
}
