import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/player_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/auth');
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const SizedBox();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar + name
                Center(
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
                          color: AppColors.darkBlue,
                        ),
                      ).animate(delay: 200.ms).fadeIn(),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        emoji: '⭐',
                        label: 'Total Points',
                        value: '${user.totalPoints}',
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '🖼️',
                        label: 'Owned Images',
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
                        label: 'Themes',
                        value: '${user.purchasedThemeIds.length}',
                        gradient: AppColors.accentGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        emoji: '🏆',
                        label: 'Win Bonus',
                        value: '+10~40',
                        gradient: const LinearGradient(
                          colors: [AppColors.warning, Color(0xFFFF8C00)],
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.2),

                const SizedBox(height: 28),

                // Points info box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 How to earn points',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PointInfo('🧩 Place a piece', '+1 to +4 pts (by difficulty)'),
                      _PointInfo('🏆 Correct guess', '+10 to +40 pts (by difficulty)'),
                      _PointInfo('❌ Wrong guess', '-1 to -4 pts (by difficulty)'),
                      _PointInfo('👑 Host vote', 'Your vote counts ×2'),
                    ],
                  ),
                ).animate(delay: 500.ms).fadeIn(),

                const SizedBox(height: 24),

                GradientButton(
                  text: 'Go to Store',
                  icon: Icons.store_rounded,
                  gradient: AppColors.secondaryGradient,
                  onPressed: () => context.push('/store'),
                ).animate(delay: 600.ms).fadeIn(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.darkBlue,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
