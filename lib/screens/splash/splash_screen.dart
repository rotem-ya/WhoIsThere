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
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      final authState = ref.read(firebaseUserProvider);
      authState.whenData((user) {
        if (user != null) {
          context.go('/home');
        } else {
          context.go('/auth');
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
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
                    textDirection: TextDirection.ltr,
                    child: Text(
                      'Guess the Place',
                      style: AppTextStyles.titleLight.copyWith(fontSize: 32),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'חשוף את המקום לפני כולם',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subtitleLight,
                  ),
                  SizedBox(height: mathMax(40, constraints.maxHeight * 0.16)),
                  AnimatedBuilder(
                    animation: _dotController,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          final phase =
                              (_dotController.value + index / 3) % 1.0;
                          return Container(
                            width: 8 + phase * 5,
                            height: 8,
                            margin: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withOpacity(0.35 + phase * 0.5),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

double mathMax(double a, double b) => a > b ? a : b;

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
