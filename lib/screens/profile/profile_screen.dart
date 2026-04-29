import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }

          return Column(
            children: [
              AppHeader(
                title: 'פרופיל',
                leading: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.maybePop(context),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/auth');
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            PlayerAvatar(
                              name: user.name,
                              photoUrl: user.photoUrl,
                              radius: 50,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(user.name,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.titleDark),
                            const SizedBox(height: AppSpacing.xs),
                            Text('שחקן פעיל',
                                style: AppTextStyles.subtitleDark),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  label: 'נקודות',
                                  value: '${user.totalPoints}',
                                  icon: Icons.star_rounded)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: _StatCard(
                                  label: 'תמונות',
                                  value: '${user.purchasedImageIds.length}',
                                  icon: Icons.image_rounded)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  label: 'ערכות',
                                  value: '${user.purchasedThemeIds.length}',
                                  icon: Icons.palette_rounded)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                              child: _StatCard(
                                  label: 'ניצחון',
                                  value: '+10~40',
                                  icon: Icons.emoji_events_rounded)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _PointInfo('🧩 הנח חתיכה', '+1 עד +4 נק׳'),
                            _PointInfo('🏆 ניחוש נכון', '+10 עד +40 נק׳'),
                            _PointInfo('❌ ניחוש שגוי', '-1 עד -4 נק׳'),
                            _PointInfo('👑 הצבעת מארח', '×2'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AppButton(
                label: 'עבור לחנות',
                icon: Icons.store_rounded,
                onPressed: () => context.push('/store'),
              ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
            child: Text('שגיאה: $e', style: AppTextStyles.subtitleLight)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(value,
              textDirection: TextDirection.ltr, style: AppTextStyles.titleDark),
          Text(label, style: AppTextStyles.subtitleDark),
        ],
      ),
    );
  }
}

class _PointInfo extends StatelessWidget {
  final String label;
  final String value;

  const _PointInfo(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value,
              textDirection: TextDirection.ltr,
              style: AppTextStyles.body.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}
