import 'dart:io' show Platform;
import 'dart:math';

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

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFFFE082);
  static const _goldDark = Color(0xFFA1811A);
  static const _navy = Color(0xFF050A14);
  static const _cyan = Color(0xFF00D4FF);

  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pulseController.dispose();
    super.dispose();
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
          body: Stack(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(gradient: AppStyles.backgroundGradient),
                child: const SizedBox.expand(),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) => CustomPaint(
                    painter: _CosmicParticlesPainter(
                      animationProgress: _pulseController.value,
                    ),
                  ),
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
                          const Spacer(flex: 3),
                          const _HeroMark(),
                          const SizedBox(height: 18),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'מה בתמונה?',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                height: 1,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF000000),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(flex: 3),
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
                          const SizedBox(height: 8),
                          Text(
                            'תוכל לשמור התקדמות גם בהמשך',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.56),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const Spacer(flex: 3),
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
                            const SizedBox(height: 12),
                            _SecondaryButton(
                              label: 'המשך עם Google',
                              onTap: _signInWithGoogle,
                            ),
                            if (Platform.isIOS) ...[
                              const SizedBox(height: 12),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CosmicParticlesPainter extends CustomPainter {
  final double animationProgress;

  _CosmicParticlesPainter({this.animationProgress = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 35; i++) {
      final random = Random(i * 1237);
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final driftY = (animationProgress % 1.0) * size.height * 0.25;
      final offsetY = (y + driftY) % size.height;
      final opacity = (random.nextDouble() * 0.12) + 0.03;
      final radius = (random.nextDouble() * 0.9) + 0.3;
      canvas.drawCircle(
        Offset(x, offsetY),
        radius,
        Paint()..color = _AuthScreenState._cyan.withOpacity(opacity),
      );
    }

    for (int i = 35; i < 55; i++) {
      final random = Random(i * 1237);
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final twinkle = (sin((animationProgress * 2 * pi) + (i * 0.3)) + 1) / 2;
      final opacity = ((random.nextDouble() * 0.15) + 0.08) * (twinkle * 0.3 + 0.7);
      final radius = (random.nextDouble() * 0.5) + 0.15;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withOpacity(opacity),
      );
    }

    final hazeGradient = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00D4FF).withOpacity(0.03),
          const Color(0xFF00D4FF).withOpacity(0.0),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), hazeGradient);
  }

  @override
  bool shouldRepaint(_CosmicParticlesPainter oldDelegate) =>
      oldDelegate.animationProgress != animationProgress;
}

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
    final baseBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(
        color: Colors.white.withOpacity(0.16),
        width: 1.2,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
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
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.42),
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
          counterText: '',
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: baseBorder,
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: borderRadius,
                  borderSide: BorderSide(
                    color: Colors.red.shade400,
                    width: 1.4,
                  ),
                )
              : baseBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(
              color: _AuthScreenState._cyan,
              width: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMark extends StatefulWidget {
  const _HeroMark();

  @override
  State<_HeroMark> createState() => _HeroMarkState();
}

class _HeroMarkState extends State<_HeroMark> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) => Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: _AuthScreenState._navy.withOpacity(0.85),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: _AuthScreenState._cyan.withOpacity(0.25),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _MapRevealPainter(scanProgress: _scanController.value),
          ),
        ),
      ),
    );
  }
}

class _MapRevealPainter extends CustomPainter {
  final double scanProgress;

  _MapRevealPainter({required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.65,
      Paint()
        ..color = _AuthScreenState._cyan.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    final scanAngle = (scanProgress * 2 * pi) - (pi / 2);
    final sweepArc = pi / 6;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65),
      scanAngle - (sweepArc / 2),
      sweepArc,
      true,
      Paint()
        ..color = _AuthScreenState._cyan.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65),
      scanAngle,
      0.08,
      true,
      Paint()
        ..color = _AuthScreenState._cyan.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      Offset(cx, cy),
      1.6,
      Paint()..color = _AuthScreenState._cyan.withOpacity(0.5),
    );
  }

  @override
  bool shouldRepaint(_MapRevealPainter oldDelegate) =>
      oldDelegate.scanProgress != scanProgress;
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.94).animate(_pressController),
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
                color: const Color(0xFF000000).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                color: _AuthScreenState._navy,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.96).animate(_pressController),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _AuthScreenState._cyan.withOpacity(0.24),
              width: 1.2,
            ),
            color: _AuthScreenState._navy.withOpacity(0.25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
