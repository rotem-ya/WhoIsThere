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
                          SizedBox(height: constraints.maxHeight * 0.12),
                          // Premium puzzle logo with crystal glow effect
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              final value = _pulseController.value;
                              return Transform.scale(
                                scale: 0.98 + value * 0.04,
                                child: Container(
                                  width: 180,
                                  height: 180,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.3),
                                        AppColors.accent.withOpacity(0.2),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent
                                            .withOpacity(0.4 + value * 0.2),
                                        blurRadius: 40 + value * 20,
                                        spreadRadius: 4 + value * 6,
                                      ),
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withOpacity(0.3 + value * 0.15),
                                        blurRadius: 60 + value * 30,
                                        spreadRadius: 2 + value * 4,
                                      ),
                                    ],
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: const _PremiumPuzzleLogo(),
                          )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(curve: Curves.easeOutBack),
                          SizedBox(height: constraints.maxHeight * 0.08),
                          // Title with magical glow
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.white.withOpacity(0.95),
                                  ],
                                ).createShader(bounds),
                                child: Text(
                                  'מה בתמונה?',
                                  style: AppTextStyles.titleLight.copyWith(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: AppColors.accent.withOpacity(0.5),
                                        blurRadius: 20,
                                      ),
                                      Shadow(
                                        color: AppColors.primary.withOpacity(0.3),
                                        blurRadius: 40,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'חשוף רמזים ונחש את המילה',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitleLight.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          // Premium glossy button with gradient
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  final authState = ref.read(firebaseUserProvider);
                                  authState.whenData((user) {
                                    if (user != null) {
                                      context.go('/home');
                                    } else {
                                      context.go('/auth');
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(28),
                                child: Container(
                                  width: double.infinity,
                                  height: 60,
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'צור חדר',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
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

class _PremiumPuzzleLogo extends StatelessWidget {
  const _PremiumPuzzleLogo();

  @override
  Widget build(BuildContext context) {
    // TODO: replace with premium crystal puzzle asset
    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (context, index) {
            final revealed = index == 1 || index == 4 || index == 6;
            return Container(
              decoration: BoxDecoration(
                gradient: revealed
                    ? LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(revealed ? 0.4 : 0.2),
                  width: 1.5,
                ),
                boxShadow: revealed
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  revealed ? '✨' : '?',
                  style: TextStyle(
                    color: revealed ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: revealed ? 18 : 16,
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
