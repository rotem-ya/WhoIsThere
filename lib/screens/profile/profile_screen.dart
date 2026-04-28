import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/premium_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return PremiumScaffold(
      showBeams: true,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                PremiumScreenHeader(
                  eyebrow: 'PLAYER CARD',
                  title: user.name,
                  subtitle: 'הפרופיל, הנקודות וההתקדמות שלך',
                  icon: Icons.person_rounded,
                  trailing: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    onPressed: () async {
                      await ref.read(authServiceProvider).signOut();
                      if (context.mounted) context.go('/auth');
                    },
                  ),
                ),
                const SizedBox(height: 18),
                PremiumGlassCard(
                  child: Column(
                    children: [
                      PlayerAvatar(
                        name: user.name,
                        photoUrl: user.photoUrl,
                        radius: 48,
                      ).animate().scale(curve: Curves.elasticOut),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ).animate(delay: 200.ms).fadeIn(),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        emoji: '⭐',
                        label: 'סה"כ נקודות',
                        value: '${user.totalPoints}',
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '🖼️',
                        label: 'תמונות שבבעלותך',
                        value: '${user.purchasedImageIds.length}',
                        gradient: AppColors.secondaryGradient,
                      ),
                    ),
                  ],
                ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        emoji: '🎨',
                        label: 'ערכות נושא',
                        value: '${user.purchasedThemeIds.length}',
                        gradient: AppColors.accentGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '🏆',
                        label: 'בונוס ניצחון',
                        value: '+10~40',
                        gradient: const LinearGradient(
                          colors: [AppColors.warning, Color(0xFFFF8C00)],
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),
                const SizedBox(height: 20),
                PremiumGlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 איך להרוויח נקודות',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PointInfo('🧩 הנח חתיכה', '+1 עד +4 נק׳ (לפי קושי)'),
                      _PointInfo('🏆 ניחוש נכון', '+10 עד +40 נק׳ (לפי קושי)'),
                      _PointInfo('❌ ניחוש שגוי', '-1 עד -4 נק׳ (לפי קושי)'),
                      _PointInfo('👑 הצבעת מארח', 'הצבעתך שווה ×2'),
                    ],
                  ),
                ).animate(delay: 500.ms).fadeIn(),
                const SizedBox(height: 18),
                GradientButton(
                  text: 'עבור לחנות',
                  icon: Icons.store_rounded,
                  gradient: AppColors.secondaryGradient,
                  onPressed: () => context.push('/store'),
                ).animate(delay: 600.ms).fadeIn(),
              ],
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(
          child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final LinearGradient gradient;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
