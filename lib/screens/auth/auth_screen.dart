import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/providers.dart';

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.pageBackground),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 5),
                  const _EntryHeroMark(),
                  const SizedBox(height: 36),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'מה בתמונה?',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'המשך כדי לשמור התקדמות ולשחק',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(flex: 7),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 34),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.6,
                        ),
                      ),
                    )
                  else ...[
                    _PrimaryEntryButton(
                      label: 'המשך כאורח',
                      onPressed: _signInAnonymously,
                    ),
                    const SizedBox(height: 12),
                    _SecondaryEntryButton(
                      label: 'המשך עם Google',
                      onPressed: _signInWithGoogle,
                    ),
                    if (isIOS) ...[
                      const SizedBox(height: 12),
                      _SecondaryEntryButton(
                        label: 'המשך עם Apple',
                        onPressed: _signInWithApple,
                      ),
                    ],
                  ],
                  const SizedBox(height: 42),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryHeroMark extends StatelessWidget {
  const _EntryHeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 188,
        height: 188,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(54),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.16),
              Colors.white.withOpacity(0.07),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.20), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF29E6FF).withOpacity(0.20),
              blurRadius: 48,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 104,
            height: 104,
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
              ),
              itemCount: 9,
              itemBuilder: (context, index) {
                final revealed = index == 1 || index == 4 || index == 8;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: revealed
                        ? const Color(0xFF35D9D0)
                        : Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: revealed
                          ? const Color(0xFF78FFF2)
                          : Colors.white.withOpacity(0.22),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      revealed ? '✦' : '?',
                      style: TextStyle(
                        color: revealed ? const Color(0xFFFFD740) : Colors.white70,
                        fontSize: revealed ? 22 : 23,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryEntryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF35D9FF), Color(0xFF6A43FF), Color(0xFFFF4EB8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A43FF).withOpacity(0.42),
              blurRadius: 28,
              offset: const Offset(0, 11),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryEntryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.32)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: Colors.white.withOpacity(0.08),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}
