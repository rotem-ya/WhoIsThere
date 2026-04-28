import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/premium_scaffold.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLoading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null && mounted) {
        context.go('/home');
      }
    } catch (_) {
      // signInWithGoogle already falls back inside AuthService.
      // If it still threw, try anonymous directly without showing an error.
      try {
        final user = await ref.read(authServiceProvider).signInAnonymously();
        if (user != null && mounted) context.go('/home');
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authServiceProvider).signInAnonymously();
      if (user != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ההתחברות נכשלה: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final user = await ref.read(authServiceProvider).signInWithApple();
      if (user != null && mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ההתחברות נכשלה: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;

    return PremiumScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 36),
              const HeroPuzzleMark(size: 118)
                  .animate()
                  .scale(duration: 620.ms, curve: Curves.elasticOut),
              const SizedBox(height: 22),
              const Text(
                'Guess the Place',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.25),
              const SizedBox(height: 8),
              Text(
                'חשוף רמזים, זהה מקומות, ונצח את כולם.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ).animate(delay: 360.ms).fadeIn(),
              const SizedBox(height: 34),
              PremiumGlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'כניסה למשחק',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'בחר דרך התחברות והיכנס לחדר תוך רגע',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.66),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_isLoading)
                      const CircularProgressIndicator(color: AppColors.accent)
                    else ...[
                      _SocialSignInButton(
                        onPressed: _signInWithGoogle,
                        icon: '🌐',
                        label: 'המשך עם Google',
                        color: Colors.white,
                        textColor: AppColors.darkBlue,
                        borderColor: Colors.white,
                      ),
                      if (isIOS) ...[
                        const SizedBox(height: 12),
                        _SocialSignInButton(
                          onPressed: _signInWithApple,
                          icon: '🍎',
                          label: 'המשך עם Apple',
                          color: Colors.black,
                          textColor: Colors.white,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SocialSignInButton(
                        onPressed: _signInAnonymously,
                        icon: '👤',
                        label: 'המשך כאורח',
                        color: Colors.white.withOpacity(0.12),
                        textColor: Colors.white,
                        borderColor: Colors.white.withOpacity(0.24),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'כולל הדגמות, בוטים ומשחק מהיר',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.58),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 560.ms).fadeIn().slideY(begin: 0.28),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;

  const _SocialSignInButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          AppFeedback.selection();
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: borderColor != null ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor != null
                ? BorderSide(color: borderColor!, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
