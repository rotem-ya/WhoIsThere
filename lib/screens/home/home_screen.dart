import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/player_avatar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F9FF), Color(0xFFEEF0FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          userAsync.when(
                            data: (user) => Text(
                              'Hi, ${user?.name.split(' ').first ?? 'Player'}! 👋',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkBlue,
                              ),
                            ),
                            loading: () => const SizedBox(height: 28),
                            error: (_, __) => const Text('Welcome!'),
                          ),
                          const Text(
                            'Ready to play?',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Points badge
                        userAsync.when(
                          data: (user) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.warning, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '${user?.totalPoints ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.darkBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: userAsync.when(
                            data: (user) => PlayerAvatar(
                              name: user?.name ?? 'P',
                              photoUrl: user?.photoUrl,
                              radius: 22,
                            ),
                            loading: () => const CircleAvatar(radius: 22),
                            error: (_, __) => const CircleAvatar(radius: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms),

                const SizedBox(height: 32),

                // Big puzzle icon
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🧩', style: TextStyle(fontSize: 90)),
                    ),
                  ),
                )
                    .animate(delay: 200.ms)
                    .scale(curve: Curves.elasticOut, duration: 700.ms)
                    .fadeIn(),

                const SizedBox(height: 16),

                const Center(
                  child: Text(
                    'WhoIsThere?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(),

                const Spacer(),

                // Action buttons
                GradientButton(
                  text: 'Create Room',
                  icon: Icons.add_rounded,
                  gradient: AppColors.primaryGradient,
                  onPressed: () => context.push('/create-room'),
                ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 12),

                GradientButton(
                  text: 'Join Room',
                  icon: Icons.login_rounded,
                  gradient: AppColors.secondaryGradient,
                  onPressed: () => context.push('/join-room'),
                ).animate(delay: 600.ms).fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/store'),
                        icon: const Icon(Icons.store_rounded),
                        label: const Text('Store'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/profile'),
                        icon: const Icon(Icons.person_rounded),
                        label: const Text('Profile'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ).animate(delay: 700.ms).fadeIn(),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
