import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_styles.dart';
import '../../core/utils/display_name_sanitizer.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';

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
  void initState() {
    super.initState();
    QaLoggerService.instance.log('AUTH', 'AUTH_SCREEN_OPENED');
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
                        const Spacer(flex: 2),

                        // ── Aperture hero ────────────────────────────────────
                        const _ApertureHero(),
                        const SizedBox(height: 20),
                        const Text(
                          'מה בתמונה?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
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

                        const Spacer(flex: 2),

                        // ── Name field ───────────────────────────────────────
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
                        ] else ...[
                          const SizedBox(height: 6),
                          Text(
                            'אתה יכול לשחק כאורח בלי לכניס שם',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
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
                          _PrimaryButton(
                            label: 'התחל לשחק',
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

                        const SizedBox(height: 32),
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

// ── Aperture hero ──────────────────────────────────────────────────────────

class _ApertureHero extends StatelessWidget {
  const _ApertureHero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _AuthScreenState._gold.withOpacity(0.16),
              blurRadius: 48,
              spreadRadius: 6,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _AperturePainter(),
        ),
      ),
    );
  }
}

class _AperturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = const Color(0xFF060C1A),
    );

    // 6 aperture blades in gold
    final bladePaint = Paint()
      ..color = _AuthScreenState._gold
      ..style = PaintingStyle.fill;

    final outerR = r * 0.84;
    final innerR = r * 0.26;

    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      final outerA1 = a - pi / 9; // outer arc start (~−20°)
      final outerA2 = a + pi / 9; // outer arc end   (~+20°)
      final innerA = a + pi / 3;  // inner tip twisted to next blade's angle

      final p1 = Offset(cx + outerR * cos(outerA1), cy + outerR * sin(outerA1));
      final p2 = Offset(cx + outerR * cos(outerA2), cy + outerR * sin(outerA2));
      final p3 = Offset(cx + innerR * cos(innerA), cy + innerR * sin(innerA));

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..arcToPoint(p2, radius: Radius.circular(outerR), clockwise: true)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      canvas.drawPath(path, bladePaint);
    }

    // Center dark opening (lens)
    canvas.drawCircle(
      Offset(cx, cy),
      innerR * 0.68,
      Paint()..color = const Color(0xFF020407),
    );

    // Outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      r - 1,
      Paint()
        ..color = _AuthScreenState._gold.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_AperturePainter old) => false;
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
        height: 56,
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
