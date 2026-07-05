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

  static bool _introPlayed = false;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const _gold  = Color(0xFFD4AF37);

  late final bool _doIntro;
  bool _isLoading  = false;
  bool _showGuest  = false; // expands name field + guest button

  final _nameController = TextEditingController();
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _doIntro = !AuthScreen._introPlayed;
    AuthScreen._introPlayed = true;
    QaLoggerService.instance.log('AUTH', 'AUTH_SCREEN_OPENED');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Widget _step(Widget w, {required int delayMs, required int durationMs, double dy = 0}) {
    if (!_doIntro) return w;
    var a = w
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs),
            duration: Duration(milliseconds: durationMs), curve: Curves.easeOut);
    if (dy != 0) {
      a = a.moveY(
          begin: dy,
          end: 0,
          delay: Duration(milliseconds: delayMs),
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOut);
    }
    return a;
  }

  String? _resolvedName() {
    final raw = _nameController.text.trim();
    if (raw.isEmpty) return null;
    final sanitized = DisplayNameSanitizer.sanitize(raw);
    if (sanitized == null) {
      setState(() => _nameError = '2–16 תווים, אותיות ומספרים בלבד');
      return 'invalid';
    }
    return sanitized;
  }

  Future<void> _runAuth(Future<dynamic> Function() action, {String logTag = 'AUTH'}) async {
    setState(() => _isLoading = true);
    try {
      final user = await action();
      if (user != null && mounted) {
        QaLoggerService.instance.log('AUTH', '${logTag}_SUCCESS');
        if (logTag == 'AUTH_GOOGLE' || logTag == 'AUTH_APPLE') {
          final label = logTag == 'AUTH_GOOGLE' ? 'Google' : 'Apple';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('מחובר עם $label ✓',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: const Color(0xFF1B5E20),
            duration: const Duration(seconds: 3),
          ));
        }
        context.go('/home');
      }
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('AUTH', 'AUTH_ERROR [$logTag] ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ההתחברות נכשלה: $e'),
          backgroundColor: Colors.red.shade900,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    QaLoggerService.instance.log('AUTH', 'AUTH_GOOGLE_ATTEMPT');
    await _runAuth(() => ref.read(authServiceProvider).signInWithGoogle(), logTag: 'AUTH_GOOGLE');
  }

  Future<void> _signInWithApple() async {
    if (Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('התחברות עם Apple זמינה ב-iPhone בלבד',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontWeight: FontWeight.w700)),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    QaLoggerService.instance.log('AUTH', 'AUTH_APPLE_ATTEMPT');
    await _runAuth(() => ref.read(authServiceProvider).signInWithApple(), logTag: 'AUTH_APPLE');
  }

  Future<void> _signInAnonymously() async {
    final name = _resolvedName();
    if (name == 'invalid') return;
    QaLoggerService.instance.log('AUTH', 'AUTH_ANON_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
      logTag: 'AUTH_ANON',
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

                            // Logo
                            _step(
                              const RepaintBoundary(child: AppLogo(size: 150)),
                              delayMs: 0, durationMs: 500, dy: 12,
                            ),
                            const SizedBox(height: 18),

                            // Title
                            _step(
                              const Text(
                                'מה בתמונה?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 50,
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

                            // Subtitle
                            _step(
                              const Text(
                                'גלה חלקים · נחש את המקום',
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

                            const Spacer(flex: 3),

                            if (_isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 24),
                                  child: CircularProgressIndicator(color: _gold, strokeWidth: 2.4),
                                ),
                              )
                            else ...[

                              // ── Primary: Google (hidden on iOS — Google
                              // sign-in isn't configured for iOS) ─────────────
                              if (!Platform.isIOS) ...[
                                _step(
                                  _SocialButton(
                                    label: 'כניסה עם Google',
                                    icon: _GoogleIcon(),
                                    isPrimary: true,
                                    onTap: _signInWithGoogle,
                                  ),
                                  delayMs: 360, durationMs: 300, dy: 8,
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ── Primary: Apple (always shown — disabled on Android) ──
                              _step(
                                _SocialButton(
                                  label: 'כניסה עם Apple',
                                  icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                                  isPrimary: true,
                                  onTap: _signInWithApple,
                                ),
                                delayMs: 460, durationMs: 300, dy: 8,
                              ),

                              const SizedBox(height: 24),

                              // ── Divider ─────────────────────────────────────
                              _step(
                                Row(children: [
                                  Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('או',
                                        style: TextStyle(
                                            color: Colors.white.withOpacity(0.35),
                                            fontSize: 13)),
                                  ),
                                  Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                                ]),
                                delayMs: 540, durationMs: 280,
                              ),

                              const SizedBox(height: 16),

                              // ── Guest section (expandable) ──────────────────
                              _step(
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_showGuest) ...[
                                        // Name field (optional)
                                        _NameField(
                                          controller: _nameController,
                                          hasError: _nameError != null,
                                          onChanged: (_) => setState(() => _nameError = null),
                                        ),
                                        if (_nameError != null) ...[
                                          const SizedBox(height: 5),
                                          Text(_nameError!,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.red.shade300,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                        const SizedBox(height: 12),
                                        GradientButton(
                                          text: 'כניסה כאורח',
                                          onPressed: _signInAnonymously,
                                          height: 50,
                                        ),
                                        const SizedBox(height: 6),
                                        TextButton(
                                          onPressed: () => setState(() {
                                            _showGuest = false;
                                            _nameController.clear();
                                            _nameError = null;
                                          }),
                                          child: Text('חזרה',
                                              style: TextStyle(
                                                  color: Colors.white.withOpacity(0.40),
                                                  fontSize: 13)),
                                        ),
                                      ] else
                                        Center(
                                          child: TextButton(
                                            onPressed: () => setState(() => _showGuest = true),
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white38,
                                              minimumSize: const Size(0, 40),
                                            ),
                                            child: const Text(
                                              'המשך ללא חיבור',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,
                                                decorationColor: Colors.white24,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                delayMs: 620, durationMs: 260,
                              ),
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

// ── Social button (Google / Apple) ────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFB8860B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : const Color(0xFF0F1A2E),
          borderRadius: BorderRadius.circular(999),
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFF87CEEB).withOpacity(0.28)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? const Color(0xFF07101F) : Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Google "G" icon ───────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          height: 1,
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
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'כינוי (אופציונלי)',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 16),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withOpacity(0.09),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: baseBorder,
        enabledBorder: hasError
            ? OutlineInputBorder(
                borderRadius: borderRadius,
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.2))
            : baseBorder,
        focusedBorder: const OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: Color(0xFF87CEEB), width: 1.5),
        ),
      ),
    );
  }
}
