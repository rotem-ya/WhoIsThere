import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/display_name_sanitizer.dart';
import '../../../providers/providers.dart';
import '../../../services/qa_logger_service.dart';

class GeminiAuthScreen extends ConsumerStatefulWidget {
  const GeminiAuthScreen({super.key});

  @override
  ConsumerState<GeminiAuthScreen> createState() => _GeminiAuthScreenState();
}

class _GeminiAuthScreenState extends ConsumerState<GeminiAuthScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('AUTH', 'GEMINI_DESIGN_OPENED');
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    QaLoggerService.instance.log('AUTH', 'GEMINI_ANON_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInAnonymously(preferredName: name),
      logTag: 'GEMINI_ANON',
    );
  }

  Future<void> _signInWithGoogle() async {
    QaLoggerService.instance.log('AUTH', 'GEMINI_GOOGLE_ATTEMPT');
    await _runAuth(
      () => ref.read(authServiceProvider).signInWithGoogle(),
      logTag: 'GEMINI_GOOGLE',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            const _GeminiBackgroundGradient(),
            const _GeminiAtmosphericGlow(),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const _GeminiVaultHeroVisual(),
                    const SizedBox(height: 30),
                    const _GeminiMainTitle(title: "מה בתמונה?"),
                    const SizedBox(height: 8),
                    const _GeminiSubtitle(text: "חשוף חלקים · נחש את המקום"),
                    const SizedBox(height: 50),
                    _GeminiGlassTextField(
                      hint: "השם שלי (אופציונלי)",
                      controller: _nameController,
                      onChanged: (_) => setState(() => _nameError = null),
                    ),
                    const SizedBox(height: 12),
                    if (_nameError != null)
                      Text(
                        _nameError!,
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      const Text(
                        "אתה יכול לשחק כאורח בלי להכניס שם",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    const SizedBox(height: 40),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: CircularProgressIndicator(
                            color: Color(0xFFFFD700),
                            strokeWidth: 2.4,
                          ),
                        ),
                      )
                    else ...[
                      _GeminiMetallicButton(
                        label: "התחל לשחק",
                        isPrimary: true,
                        onPressed: _signInAnonymously,
                      ),
                      const SizedBox(height: 16),
                      _GeminiMetallicButton(
                        label: "המשך עם Google",
                        isPrimary: false,
                        onPressed: _signInWithGoogle,
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4285F4).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'GEMINI',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeminiBackgroundGradient extends StatelessWidget {
  const _GeminiBackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.2,
          colors: [
            Color(0xFF1A2B45),
            Color(0xFF080D15),
          ],
        ),
      ),
    );
  }
}

class _GeminiAtmosphericGlow extends StatelessWidget {
  const _GeminiAtmosphericGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: -100,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: 300,
        decoration: BoxDecoration(
          radialGradient: RadialGradient(
            colors: [
              const Color(0xFF00FFFF).withOpacity(0.08),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GeminiVaultHeroVisual extends StatelessWidget {
  const _GeminiVaultHeroVisual();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10, width: 1),
            ),
          ),
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                width: 2,
              ),
            ),
          ),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C3E50), Color(0xFF000000)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFFF).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.filter_center_focus_rounded,
              size: 60,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          ..._buildFloatingCards(),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingCards() {
    return [
      _GeminiPositionedCard(angle: -0.3, offset: const Offset(-80, -60), size: 50),
      _GeminiPositionedCard(angle: 0.2, offset: const Offset(90, -40), size: 40),
      _GeminiPositionedCard(angle: -0.1, offset: const Offset(70, 70), size: 45),
    ];
  }
}

class _GeminiPositionedCard extends StatelessWidget {
  final double angle;
  final Offset offset;
  final double size;

  const _GeminiPositionedCard({
    required this.angle,
    required this.offset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
          ),
          child: const Icon(Icons.image_outlined, color: Colors.white38, size: 20),
        ),
      ),
    );
  }
}

class _GeminiMainTitle extends StatelessWidget {
  final String title;
  const _GeminiMainTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        foreground: Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFAAAAAA)],
          ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 8),
          Shadow(color: Color(0xFF00FFFF), offset: Offset(0, 0), blurRadius: 2),
        ],
      ),
    );
  }
}

class _GeminiSubtitle extends StatelessWidget {
  final String text;
  const _GeminiSubtitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF00E5FF),
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _GeminiGlassTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _GeminiGlassTextField({
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLength: 16,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _GeminiMetallicButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _GeminiMetallicButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = isPrimary
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD700), Color(0xFFB8860B), Color(0xFF8B4513)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF454545), Color(0xFF232323)],
          );

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? const Color(0xFFFFF8DC).withOpacity(0.5) : Colors.white12,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary ? const Color(0xFFB8860B).withOpacity(0.4) : Colors.black,
              offset: const Offset(0, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPrimary ? Colors.black87 : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
