import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_styles.dart';
import '../../core/utils/display_name_sanitizer.dart';
import '../../providers/providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFFFE082);
  static const _goldDark = Color(0xFFA1811A);
  static const _navy = Color(0xFF050A14);
  static const _cyan = Color(0xFF87CEEB);

  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Returns the sanitized name to use, or null if field is empty (use guestFallback).
  /// Sets [_nameError] and returns the sentinel 'invalid' if input is non-empty but invalid.
  String? _resolvedName() {
    final raw = _nameController.text.trim();
    if (raw.isEmpty) return null; // caller uses guestFallback
    final sanitized = DisplayNameSanitizer.sanitize(raw);
    if (sanitized == null) {
      setState(() => _nameError = '2–16 תווים, אותיות ומספרים בלבד');
      return 'invalid';
    }
    return sanitized;
  }

  Future<void> _runAuth(Future<dynamic> Function() action) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
      if (user != null && mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ההתחברות נכשלה: ${e.toString()}'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    final name = _resolvedName();
    if (name == 'invalid') return;
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
    );
  }

  Future<void> _signInWithGoogle() async {
    // Name field is ignored for Google — provider supplies display name.
    // null return = cancelled picker — stays on screen.
    // Exception propagates → snackbar shown, user stays on screen.
    await _runAuth(() => ref.read(authServiceProvider).signInWithGoogle());
  }

  Future<void> _signInWithApple() async {
    await _runAuth(() => ref.read(authServiceProvider).signInWithApple());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppStyles.navyTop,
          resizeToAvoidBottomInset: true,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppStyles.backgroundGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 3),

                        // ── Brand mark ───────────────────────────────────────
                        const _HeroMark(),
                        const SizedBox(height: 14),
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'מה בתמונה?',
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1,
                            ),
                          ),
                        ),

                        const Spacer(flex: 3),

                        // ── Name field ───────────────────────────────────────
                        const Text(
                          'מה השם שלך במשחק?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _NameField(
                          controller: _nameController,
                          hasError: _nameError != null,
                          onChanged: (_) => setState(() => _nameError = null),
                        ),
                        if (_nameError != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            _nameError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        const Text(
                          'תוכל לשמור התקדמות גם בהמשך',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),

                        const Spacer(flex: 4),

                        // ── Action buttons ───────────────────────────────────
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: CircularProgressIndicator(
                                color: _gold,
                                strokeWidth: 2.4,
                              ),
                            ),
                          )
                        else ...[
                          _PrimaryButton(
                            label: 'המשך כאורח',
                            onTap: _signInAnonymously,
                          ),
                          const SizedBox(height: 10),
                          _SecondaryButton(
                            label: 'המשך עם Google',
                            onTap: _signInWithGoogle,
                          ),
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 10),
                            _SecondaryButton(
                              label: 'המשך עם Apple',
                              onTap: _signInWithApple,
                            ),
                          ],
                        ],

                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Name text field ────────────────────────────────────────────────────────

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _NameField({
    required this.controller,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(16));
    const baseBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: Colors.white24),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLength: 16,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        hintText: 'שם מוצג...',
        hintStyle: const TextStyle(
          color: Colors.white30,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: baseBorder,
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
              )
            : baseBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: _AuthScreenState._cyan, width: 1.5),
        ),
      ),
    );
  }
}

// ── Hero mark ──────────────────────────────────────────────────────────────

class _HeroMark extends StatelessWidget {
  const _HeroMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          color: _AuthScreenState._navy.withOpacity(0.72),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: _AuthScreenState._gold.withOpacity(0.50),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _AuthScreenState._gold.withOpacity(0.14),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.auto_awesome_rounded,
            color: _AuthScreenState._gold,
            size: 52,
          ),
        ),
      ),
    );
  }
}

// ── Primary button (gold) ──────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              _AuthScreenState._goldLight,
              _AuthScreenState._gold,
              _AuthScreenState._goldDark,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: _AuthScreenState._gold.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: _AuthScreenState._navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Secondary button (outline) ─────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: Colors.white,
        side: BorderSide(color: _AuthScreenState._cyan.withOpacity(0.28)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        backgroundColor: _AuthScreenState._navy.withOpacity(0.30),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
