import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/premium_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 760;

    return PremiumScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight - 32),
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
                                    color: Colors.white,
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
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        userAsync.when(
                          data: (user) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: AppColors.warning, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '${user?.totalPoints ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
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
                      child: PremiumGlassCard(
                        padding: const EdgeInsets.all(18),
                        radius: 38,
                        child: SizedBox(
                          width: isSmall ? 150 : 184,
                          height: isSmall ? 150 : 184,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.36),
                                      blurRadius: 34,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const _PuzzlePreview(),
                              const Positioned(
                                bottom: 10,
                                child: Text(
                                  'READY?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                        .animate(delay: 120.ms)
                        .scale(curve: Curves.easeOutBack, duration: 550.ms),
                    SizedBox(height: isSmall ? 14 : 22),
                    const Center(
                      child: Text(
                        'Guess the Place',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
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
                          color: Colors.white70,
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
                    const SizedBox(height: 16),
                    const _FeatureStrip().animate(delay: 540.ms).fadeIn(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PuzzlePreview extends StatelessWidget {
  const _PuzzlePreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          final revealed = index == 1 || index == 4 || index == 6;
          return Container(
            decoration: BoxDecoration(
              color: revealed
                  ? Colors.white.withOpacity(0.95)
                  : Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.28)),
            ),
            child: Center(
              child: Text(
                revealed
                    ? ['🗼', '🏛️', '🌉'][index == 1
                        ? 0
                        : index == 4
                            ? 1
                            : 2]
                    : '?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.88),
                  fontWeight: FontWeight.w900,
                  fontSize: revealed ? 17 : 15,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeatureStrip extends StatelessWidget {
  const _FeatureStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('⚡', 'מהיר'),
      ('🎧', 'חי'),
      ('🏆', 'תחרותי'),
    ];
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PremiumGlassCard(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              radius: 18,
              child: Column(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
