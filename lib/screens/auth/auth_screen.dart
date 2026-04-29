import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';

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
      if (user != null && mounted) context.go('/home');
    } catch (_) {
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
      if (user != null && mounted) context.go('/home');
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
      if (user != null && mounted) context.go('/home');
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

    return AppScaffold(
      backgroundGradient: AppColors.pageBackground,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  const _IdentityHero(),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'כניסה למשחק',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleDark,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'התחברו, צרו חדר, והתחילו לחשוף את התמונה.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.subtitleDark,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_isLoading)
                          const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        else ...[
                          AppButton(
                            label: 'המשך עם Google',
                            icon: Icons.public_rounded,
                            onPressed: _signInWithGoogle,
                          ),
                          if (isIOS) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _SecondaryAuthButton(
                              label: 'המשך עם Apple',
                              icon: Icons.apple_rounded,
                              onPressed: _signInWithApple,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          _SecondaryAuthButton(
                            label: 'המשך כאורח',
                            icon: Icons.person_outline_rounded,
                            onPressed: _signInAnonymously,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IdentityHero extends StatelessWidget {
  const _IdentityHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(42),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: const Center(
            child: Text('🗺️', style: TextStyle(fontSize: 76)),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Guess the Place', style: AppTextStyles.titleLight),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'משחק ניחוש מקומות מרובה משתתפים',
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitleLight,
        ),
      ],
    );
  }
}

class _SecondaryAuthButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _SecondaryAuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        AppFeedback.selection();
        onPressed();
      },
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.xl + AppSpacing.lg),
        foregroundColor: AppColors.primary,
        textStyle: AppTextStyles.button.copyWith(color: AppColors.primary),
        side: BorderSide(color: AppColors.primary.withOpacity(0.24)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
