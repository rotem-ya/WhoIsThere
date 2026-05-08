import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFFFE082);
  static const goldDark = Color(0xFFA1811A);
  static const navyBlack = Color(0xFF050A14);
  static const cyan = Color(0xFF87CEEB);

  bool _isLoading = false;

  Future<void> _runAuth(Future<dynamic> Function() action) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
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

  Future<void> _signInWithGoogle() async {
    await _runAuth(() async {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      return user ?? await ref.read(authServiceProvider).signInAnonymously();
    });
  }

  Future<void> _signInAnonymously() => _runAuth(ref.read(authServiceProvider).signInAnonymously);
  Future<void> _signInWithApple() => _runAuth(ref.read(authServiceProvider).signInWithApple);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppStyles.backgroundGradient),
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
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'המשך כדי לשמור התקדמות ולשחק',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w600, height: 1.25),
                  ),
                  const Spacer(flex: 7),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 34),
                        child: CircularProgressIndicator(color: gold, strokeWidth: 2.6),
                      ),
                    )
                  else ...[
                    _PrimaryEntryButton(label: 'המשך כאורח', onPressed: _signInAnonymously),
                    const SizedBox(height: 12),
                    _SecondaryEntryButton(label: 'המשך עם Google', onPressed: _signInWithGoogle),
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 12),
                      _SecondaryEntryButton(label: 'המשך עם Apple', onPressed: _signInWithApple),
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
          color: _AuthScreenState.navyBlack.withOpacity(0.72),
          borderRadius: BorderRadius.circular(54),
          border: Border.all(color: _AuthScreenState.gold.withOpacity(0.55), width: 2),
          boxShadow: [
            BoxShadow(color: _AuthScreenState.gold.withOpacity(0.16), blurRadius: 44, spreadRadius: 3),
            BoxShadow(color: _AuthScreenState.cyan.withOpacity(0.10), blurRadius: 54, spreadRadius: 6),
          ],
        ),
        child: const Center(
          child: Icon(Icons.auto_awesome_rounded, color: _AuthScreenState.gold, size: 78),
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
            colors: [_AuthScreenState.goldLight, _AuthScreenState.gold, _AuthScreenState.goldDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: _AuthScreenState.gold.withOpacity(0.34), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: const Center(
          child: Text('המשך כאורח', style: TextStyle(color: _AuthScreenState.navyBlack, fontSize: 25, fontWeight: FontWeight.w900, height: 1)),
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
        side: BorderSide(color: _AuthScreenState.cyan.withOpacity(0.30)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: _AuthScreenState.navyBlack.withOpacity(0.34),
      ),
      child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
    );
  }
}
