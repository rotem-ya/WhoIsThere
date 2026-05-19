import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_styles.dart';
import '../../core/utils/display_name_sanitizer.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/pressable_scale.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  // Intro plays only on first open per session (e.g. not replayed after sign-out/sign-in).
  static bool _introPlayed = false;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF050A14);
  static const _cyan = Color(0xFF87CEEB);

  final _nameController = TextEditingController();
  late final bool _doIntro;
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _doIntro = !AuthScreen._introPlayed;
    AuthScreen._introPlayed = true;
    QaLoggerService.instance.log('AUTH', 'AUTH_SCREEN_OPENED');
  }

  Widget _step(Widget w, {required int delayMs, required int durationMs, double dy = 0}) {
    if (!_doIntro) return w;
    var a = w.animate().fadeIn(
      delay: Duration(milliseconds: delayMs),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOut,
    );
    if (dy != 0) {
      a = a.moveY(
        begin: dy,
        end: 0,
        delay: Duration(milliseconds: delayMs),
        duration: Duration(milliseconds: durationMs),
        curve: Curves.easeOut,
      );
    }
    return a;
  }

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

  Future<void> _runAuth(
    Future<dynamic> Function() action, {
    String logTag = 'AUTH',
  }) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
      if (user != null && mounted) {
        QaLoggerService.instance.log('AUTH', '${logTag}_SUCCESS');
        context.go('/home');
      }
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log(
          'AUTH', 'AUTH_ERROR [$logTag] ${msg.length > 80 ? msg.substring(0, 80) : msg}');
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
    if (name != null) QaLoggerService.instance.log('AUTH', 'AUTH_NAME_PRESENT name=$name');
    QaLoggerService.instance.log('AUTH', 'AUTH_ANON_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
      logTag: 'AUTH_ANON',
    );
  }

  Future<void> _signInWithGoogle() async {
    // null = user cancelled picker — _runAuth stays on screen (no navigation).
    // Exception = Google unavailable — _runAuth shows snackbar, user can tap Guest.
    QaLoggerService.instance.log('AUTH', 'AUTH_GOOGLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithGoogle(),
      logTag: 'AUTH_GOOGLE',
    );
  }

  Future<void> _signInWithApple() async {
    QaLoggerService.instance.log('AUTH', 'AUTH_APPLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithApple(),
      logTag: 'AUTH_APPLE',
    );
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
            child: Stack(
              children: [
                const Positioned.fill(
                  child: RepaintBoundary(
                    child: AmbientBackground(intensity: 0.60),
                  ),
                ),
                SafeArea(
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
                        const Spacer(flex: 2),

                        // Step 1 — logo
                        _step(
                          const RepaintBoundary(child: AppLogo(size: 160)),
                          delayMs: 0, durationMs: 500, dy: 12,
                        ),
                        const SizedBox(height: 20),

                        // Step 2 — title
                        _step(
                          const Text(
                            'מה בתמונה?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1,
                              shadows: [
                                Shadow(color: Color(0xCC000000), blurRadius: 18),
                                Shadow(color: Color(0xFF07101F), blurRadius: 32, offset: Offset(0, 4)),
                                Shadow(color: Color(0x66D4AF37), blurRadius: 48, offset: Offset(0, 8)),
                              ],
                            ),
                          ),
                          delayMs: 120, durationMs: 400, dy: 8,
                        ),

                        const SizedBox(height: 8),

                        // Step 3 — subtitle
                        _step(
                          const Text(
                            'חשוף חלקים · נחש את המקום',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.6,
                              height: 1.4,
                            ),
                          ),
                          delayMs: 220, durationMs: 350,
                        ),

                        const Spacer(flex: 2),

                        // Step 4 — name field
                        _step(
                          _NameField(
                            controller: _nameController,
                            hasError: _nameError != null,
                            onChanged: (_) => setState(() => _nameError = null),
                          ),
                          delayMs: 340, durationMs: 350, dy: 8,
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

                        const Spacer(flex: 3),

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
                          // Step 5 — primary CTA
                          _step(
                            Stack(
                              children: [
                                Positioned.fill(
                                  child: SoftPulse(
                                    minOpacity: 0.0,
                                    maxOpacity: 0.26,
                                    period: const Duration(milliseconds: 2600),
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(Radius.circular(999)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0xFFD4AF37),
                                            blurRadius: 28,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                GradientButton(
                                  text: 'כנס לזירה',
                                  onPressed: _signInAnonymously,
                                  height: 56,
                                ),
                              ],
                            ),
                            delayMs: 480, durationMs: 300, dy: 8,
                          ),
                          const SizedBox(height: 10),
                          // Step 6 — secondary CTAs
                          _step(
                            _SecondaryButton(
                              label: 'כניסה עם Google',
                              onTap: _signInWithGoogle,
                            ),
                            delayMs: 600, durationMs: 280,
                          ),
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 10),
                            _step(
                              _SecondaryButton(
                                label: 'כניסה עם Apple',
                                onTap: _signInWithApple,
                              ),
                              delayMs: 700, durationMs: 280,
                            ),
                          ],
                        ],

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
              ],
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
      textInputAction: TextInputAction.done,
      autocorrect: false,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      decoration: InputDecoration(
        hintText: 'השם שלי (אופציונלי)',
        hintStyle: const TextStyle(
          color: Colors.white30,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
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
        minimumSize: const Size.fromHeight(48),
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
