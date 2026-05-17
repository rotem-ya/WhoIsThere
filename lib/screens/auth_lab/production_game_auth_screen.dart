import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/display_name_sanitizer.dart';
import '../../../providers/providers.dart';
import '../../../services/qa_logger_service.dart';

class ProductionGameAuthScreen extends ConsumerStatefulWidget {
  const ProductionGameAuthScreen({super.key});

  @override
  ConsumerState<ProductionGameAuthScreen> createState() =>
      _ProductionGameAuthScreenState();
}

class _ProductionGameAuthScreenState
    extends ConsumerState<ProductionGameAuthScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('AUTH', 'PRODUCTION_GAME_AUTH_OPENED');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleStartGame() async {
    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();
      String? sanitized;
      if (name.isNotEmpty) {
        sanitized = DisplayNameSanitizer.sanitize(name);
        if (sanitized == null) {
          setState(() {
            _nameError = '2–16 תווים, אותיות ומספרים בלבד';
            _isLoading = false;
          });
          return;
        }
      }
      QaLoggerService.instance.log('AUTH', 'GAME_START_ATTEMPT');
      final user = await ref.read(authServiceProvider).signInAnonymously(
            preferredName: sanitized,
          );
      if (user != null && mounted) {
        QaLoggerService.instance.log('AUTH', 'GAME_START_SUCCESS');
        context.go('/home');
      }
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

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      QaLoggerService.instance.log('AUTH', 'GAME_GOOGLE_ATTEMPT');
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null && mounted) {
        QaLoggerService.instance.log('AUTH', 'GAME_GOOGLE_SUCCESS');
        context.go('/home');
      }
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

  Future<void> _handleAppleSignIn() async {
    QaLoggerService.instance.log('AUTH', 'GAME_APPLE_PLACEHOLDER');
  }

  Future<void> _handlePistachioSignIn() async {
    QaLoggerService.instance.log('AUTH', 'GAME_PISTACHIO_PLACEHOLDER');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF051B3D),
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarDustPainter(),
                ),
              ),
              const Positioned.fill(
                child: _CosmicGlowLayer(),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxHeight = constraints.maxHeight;
                    final isSmallScreen = maxHeight < 700;
                    final heroSize =
                        isSmallScreen ? maxHeight * 0.22 : maxHeight * 0.28;
                    final titleFontSize = isSmallScreen ? 36.0 : 48.0;
                    final subtitleFontSize = isSmallScreen ? 13.0 : 16.0;

                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            children: [
                              SizedBox(height: isSmallScreen ? 12 : 20),
                              SizedBox(
                                height: heroSize,
                                child: const _HeroRevealGrid(),
                              ),
                              SizedBox(height: isSmallScreen ? 16 : 24),
                              _TitleSection(
                                titleFontSize: titleFontSize,
                                subtitleFontSize: subtitleFontSize,
                              ),
                              SizedBox(height: isSmallScreen ? 20 : 28),
                              _InputSection(nameController: _nameController),
                              if (_nameError != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _nameError!,
                                  style: TextStyle(
                                    color: Colors.red.shade300,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                Text(
                                  'ניתן לשחק כאורח ללא הרשמה',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                              SizedBox(height: isSmallScreen ? 16 : 24),
                              if (_isLoading)
                                const SizedBox(
                                  height: 54,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFFFE082),
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                )
                              else
                                _ActionButtonsSection(
                                  onStartGame: _handleStartGame,
                                  onGoogle: _handleGoogleSignIn,
                                  onApple: _handleAppleSignIn,
                                  onPistachio: _handlePistachioSignIn,
                                ),
                              SizedBox(height: isSmallScreen ? 8 : 16),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CosmicGlowLayer extends StatelessWidget {
  const _CosmicGlowLayer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 1.3,
          colors: [
            const Color(0xFF0077FF).withOpacity(0.12),
            const Color(0xFF00E5FF).withOpacity(0.04),
            const Color(0xFF051B3D),
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }
}

class _StarDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 120; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.2;
      final opacity = random.nextDouble() * 0.5 + 0.08;

      paint.color = (random.nextBool()
              ? const Color(0xFF00E5FF)
              : Colors.white.withOpacity(0.8))
          .withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroRevealGrid extends StatelessWidget {
  const _HeroRevealGrid();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.12),
                blurRadius: 50,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 1.0,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: const [
                    _ScenicTile(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF9A825), Color(0xFF0277BD)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    _LockedTile(),
                    _ScenicTile(
                      gradient: LinearGradient(
                        colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: const [
                    _ScenicTile(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4FC3F7), Color(0xFFFFF176)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    _CosmicCenterTile(),
                    _ScenicTile(
                      gradient: LinearGradient(
                        colors: [Color(0xFF81C784), Color(0xFF0288D1)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: const [
                    _LockedTile(),
                    _ScenicTile(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF7043), Color(0xFF5D4037)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    _ScenicTile(
                      gradient: RadialGradient(
                        colors: [Color(0xFF00BCD4), Color(0xFF388E3C)],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _IsraelMapPainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScenicTile extends StatelessWidget {
  final Gradient gradient;

  const _ScenicTile({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(gradient: gradient),
        ),
      ),
    );
  }
}

class _LockedTile extends StatelessWidget {
  const _LockedTile();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF0A1A35), const Color(0xFF050D1F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: Icon(
            Icons.lock_outline_rounded,
            color: Colors.white.withOpacity(0.12),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CosmicCenterTile extends StatelessWidget {
  const _CosmicCenterTile();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              const Color(0xFF0099FF).withOpacity(0.8),
              const Color(0xFF051B3D)
            ],
            radius: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.2),
              blurRadius: 12,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Center(
          child: Icon(
            Icons.explore_rounded,
            color: Colors.white.withOpacity(0.4),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _IsraelMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset> mapPoints = [
      Offset(size.width * 0.50, size.height * 0.18),
      Offset(size.width * 0.58, size.height * 0.32),
      Offset(size.width * 0.55, size.height * 0.58),
      Offset(size.width * 0.48, size.height * 0.80),
      Offset(size.width * 0.42, size.height * 0.58),
      Offset(size.width * 0.44, size.height * 0.35),
    ];

    final path = Path()..moveTo(mapPoints[0].dx, mapPoints[0].dy);
    for (int i = 1; i < mapPoints.length; i++) {
      path.lineTo(mapPoints[i].dx, mapPoints[i].dy);
    }
    path.close();

    final fillPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final blurPaint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
    canvas.drawPath(path, blurPaint);

    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TitleSection extends StatelessWidget {
  final double titleFontSize;
  final double subtitleFontSize;

  const _TitleSection({
    required this.titleFontSize,
    required this.subtitleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Transform.translate(
              offset: const Offset(0, 3),
              child: Text(
                'מה בתמונה?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.8,
                  color: Colors.black.withOpacity(0.7),
                ),
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  const Color(0xFFFFF176),
                  const Color(0xFFFFB300),
                  const Color(0xFFF57F17),
                ],
              ).createShader(bounds),
              child: Text(
                'מה בתמונה?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'חשוף חלקים · נחש את המקום',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFF00E5FF),
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            shadows: [
              Shadow(
                color: const Color(0xFF00E5FF).withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InputSection extends StatelessWidget {
  final TextEditingController nameController;

  const _InputSection({required this.nameController});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A35).withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00E5FF).withOpacity(0.38),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: nameController,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLength: 16,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'השם שלי (אופציונלי)',
          hintStyle: TextStyle(
            color: const Color(0xFF00E5FF).withOpacity(0.35),
            fontSize: 15,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
      ),
    );
  }
}

class _ActionButtonsSection extends StatelessWidget {
  final VoidCallback onStartGame;
  final VoidCallback onGoogle;
  final VoidCallback onApple;
  final VoidCallback onPistachio;

  const _ActionButtonsSection({
    required this.onStartGame,
    required this.onGoogle,
    required this.onApple,
    required this.onPistachio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TactileButton(
          label: 'התחל לשחק',
          height: 56,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFF57F17)],
          ),
          borderColor: const Color(0xFFFFF8E1),
          textColor: const Color(0xFF3E2723),
          shadowColor: const Color(0xFFFFB300),
          fontSize: 19,
          onPressed: onStartGame,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.15),
                thickness: 0.8,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Text(
                'או',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white.withOpacity(0.15),
                thickness: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _TactileButton(
          label: 'המשך עם Google',
          height: 48,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFE8E8E8), Color(0xFFBDBDBD)],
          ),
          borderColor: Colors.white.withOpacity(0.9),
          textColor: const Color(0xFF1F1F1F),
          shadowColor: Colors.white,
          fontSize: 15,
          onPressed: onGoogle,
          icon: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _TactileButton(
          label: 'המשך עם Apple',
          height: 48,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF424242), Color(0xFF212121), Color(0xFF0D0D0D)],
          ),
          borderColor: const Color(0xFF616161),
          textColor: Colors.white,
          shadowColor: Colors.black,
          fontSize: 15,
          onPressed: onApple,
          icon: const Icon(
            Icons.apple,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(height: 10),
        _TactileButton(
          label: 'המשך עם פיסטוק',
          height: 48,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00897B), Color(0xFF00695C), Color(0xFF004D40)],
          ),
          borderColor: const Color(0xFF4DB6AC),
          textColor: Colors.white,
          shadowColor: const Color(0xFF004D40),
          fontSize: 15,
          onPressed: onPistachio,
          icon: const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFAED581),
            size: 18,
          ),
        ),
      ],
    );
  }
}

class _TactileButton extends StatelessWidget {
  final String label;
  final double height;
  final Gradient gradient;
  final Color borderColor;
  final Color textColor;
  final Color shadowColor;
  final double fontSize;
  final VoidCallback onPressed;
  final Widget? icon;

  const _TactileButton({
    required this.label,
    required this.height,
    required this.gradient,
    required this.borderColor,
    required this.textColor,
    required this.shadowColor,
    required this.fontSize,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: gradient,
          border: Border.all(color: borderColor.withOpacity(0.8), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 1,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
