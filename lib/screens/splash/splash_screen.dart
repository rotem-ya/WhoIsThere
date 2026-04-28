import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../widgets/common/premium_scaffold.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: Column(
        children: [
          const Spacer(flex: 3),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF)
                          .withOpacity(0.3 + 0.2 * _pulseController.value),
                      blurRadius: 40 + 20 * _pulseController.value,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.30),
                    Colors.white.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withOpacity(0.28),
                  width: 1.5,
                ),
              ),
              child: const Stack(
                alignment: Alignment.center,
                children: [
                  PremiumPuzzlePreview(size: 88),
                  Text('🗺️', style: TextStyle(fontSize: 54)),
                ],
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.6, 0.6),
                duration: 700.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 500.ms),
          const SizedBox(height: 36),
          const Text(
            'Guess the Place',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.3, end: 0),
          const SizedBox(height: 10),
          Text(
            'זהה מקומות מסביב לעולם',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ).animate(delay: 500.ms).fadeIn(duration: 500.ms),
          const Spacer(flex: 3),
          _LoadingDots().animate(delay: 900.ms).fadeIn(),
          const SizedBox(height: 56),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, _) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.white.withOpacity(0.3 + 0.7 * _controllers[i].value),
              ),
            );
          },
        );
      }),
    );
  }
}
