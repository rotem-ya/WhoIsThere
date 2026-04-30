import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final value = _pulseController.value;
                              return Transform.scale(
                                scale: 0.96 + value * 0.05,
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(46),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.18)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent
                                            .withOpacity(0.22 + value * 0.18),
                                        blurRadius: 30 + value * 22,
                                        spreadRadius: 2 + value * 4,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: const _SplashMark(),
                          )
                              .animate()
                              .fadeIn(duration: 450.ms)
                              .scale(curve: Curves.easeOutBack),
                          const SizedBox(height: AppSpacing.xl),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'מה בתמונה?',
                                style: AppTextStyles.titleLight
                                    .copyWith(fontSize: 40),
                                maxLines: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'חשוף רמזים ונחש את המילה',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitleLight
                                .copyWith(fontSize: 16),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          FilledButton(
                            onPressed: () {
                              final authState = ref.read(firebaseUserProvider);
                              authState.whenData((user) {
                                if (user != null) {
                                  context.go('/home');
                                } else {
                                  context.go('/auth');
                                }
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'צור חדר',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 104,
        height: 104,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final revealed = index == 1 || index == 4 || index == 6;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: revealed ? Colors.white : Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  revealed ? '📍' : '?',
                  style: TextStyle(
                    color: revealed ? AppColors.primary : Colors.white70,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
