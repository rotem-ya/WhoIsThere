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
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 760;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                userAsync.when(
                                  data: (user) => Text(
                                    'היי, ${user?.name.split(' ').first ?? 'שחקן'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isSmall ? 24 : 28,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.darkBlue,
                                    ),
                                  ),
                                  loading: () => const SizedBox(height: 32),
                                  error: (_, __) => const Text('ברוך הבא'),
                                ),
                                const Text(
                                  'זהה מקומות מוכרים לפני כולם',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          userAsync.when(
                            data: (user) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${user?.totalPoints ?? 0}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.darkBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
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
                      ).animate().fadeIn(duration: 350.ms),

                      SizedBox(height: isSmall ? 20 : 34),

                      Center(
                        child: Container(
                          width: isSmall ? 132 : 164,
                          height: isSmall ? 132 : 164,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.28),
                                blurRadius: 26,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🗺️', style: TextStyle(fontSize: 74)),
                          ),
                        ),
                      ).animate(delay: 120.ms).scale(curve: Curves.easeOutBack, duration: 550.ms),

                      SizedBox(height: isSmall ? 14 : 22),

                      const Center(
                        child: Text(
                          'Guess the Place',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.darkBlue,
                          ),
                        ),
                      ).animate(delay: 220.ms).fadeIn(),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'משחק פאזל תחרותי לזיהוי מקומות',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ).animate(delay: 280.ms).fadeIn(),

                      SizedBox(height: isSmall ? 26 : 42),

                      GradientButton(
                        text: 'צור חדר',
                        icon: Icons.add_rounded,
                        gradient: AppColors.primaryGradient,
                        onPressed: () => context.push('/create-room'),
                      ).animate(delay: 350.ms).fadeIn().slideY(begin: 0.18),

                      const SizedBox(height: 12),

                      GradientButton(
                        text: 'הצטרף לחדר',
                        icon: Icons.login_rounded,
                        gradient: AppColors.secondaryGradient,
                        onPressed: () => context.push('/join-room'),
                      ).animate(delay: 420.ms).fadeIn().slideY(begin: 0.18),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/store'),
                              icon: const Icon(Icons.store_rounded),
                              label: const Text('חנות'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/profile'),
                              icon: const Icon(Icons.person_rounded),
                              label: const Text('פרופיל'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ).animate(delay: 480.ms).fadeIn(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
