import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

class PremiumScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showBeams;
  final bool animate;

  const PremiumScaffold({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.showBeams = false,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageBackground),
        child: Stack(
          children: [
            Positioned.fill(
              child: _PremiumBackdrop(showBeams: showBeams, animate: animate),
            ),
            SafeArea(
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PremiumGlassCard extends GlassPanel {
  const PremiumGlassCard({
    super.key,
    required super.child,
    super.padding,
    super.radius,
    super.width,
  });
}

class PremiumHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData? icon;
  final VoidCallback? onBack;
  final Widget? leading;
  final Widget? trailing;

  const PremiumHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon,
    this.onBack,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumScreenHeader(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      leading: leading ??
          (onBack == null
              ? null
              : IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: onBack,
                )),
      trailing: trailing ??
          (icon == null ? null : Icon(icon, color: AppColors.accent, size: 26)),
    );
  }
}

class PremiumScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;

  const PremiumScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.58),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null || icon != null) ...[
          const SizedBox(width: 12),
          trailing ?? Icon(icon, color: AppColors.accent, size: 26),
        ],
      ],
    );
  }
}

class ArcadeHeader extends PremiumScreenHeader {
  const ArcadeHeader({
    super.key,
    required super.eyebrow,
    required super.title,
    required super.subtitle,
    super.leading,
    super.trailing,
  });
}

class AppScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onBack;
  final Widget? trailing;

  const AppScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.leadingIcon,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          if (onBack != null) ...[
            _RoundIconButton(
              icon: leadingIcon ?? Icons.arrow_back_rounded,
              onTap: onBack!,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class PremiumStatusPill extends StatelessWidget {
  final String? label;
  final String? text;
  final IconData icon;
  final Color color;

  const PremiumStatusPill({
    super.key,
    this.label,
    this.text,
    required this.icon,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label ?? text ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends PremiumStatusPill {
  const StatusPill({
    super.key,
    required String text,
    required super.icon,
    super.color,
  }) : super(text: text);
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.13),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class PremiumLogo extends StatelessWidget {
  final double size;

  const PremiumLogo({super.key, this.size = 132});

  @override
  Widget build(BuildContext context) {
    final tileSize = size / 3.6;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accent.withOpacity(0.36),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.92, end: 1.08, duration: 1800.ms),
          Transform.rotate(
            angle: -0.08,
            child: Container(
              width: size * 0.76,
              height: size * 0.76,
              padding: EdgeInsets.all(size * 0.09),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(size * 0.23),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.42),
                    blurRadius: 34,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Wrap(
                spacing: 3,
                runSpacing: 3,
                children: List.generate(9, (index) {
                  final isOpen = index == 1 || index == 4 || index == 7;
                  return Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: isOpen
                          ? Colors.white.withOpacity(0.88)
                          : Colors.white.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.20)),
                    ),
                    child: isOpen
                        ? const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.secondary,
                            size: 18,
                          )
                        : null,
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroPuzzleMark extends StatelessWidget {
  final double size;

  const HeroPuzzleMark({super.key, this.size = 132});

  @override
  Widget build(BuildContext context) {
    return PremiumLogo(size: size);
  }
}

class PremiumPuzzlePreview extends StatelessWidget {
  final double size;

  const PremiumPuzzlePreview({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.52,
      child: PremiumLogo(size: size),
    );
  }
}

class _PremiumBackdrop extends StatefulWidget {
  final bool showBeams;
  final bool animate;

  const _PremiumBackdrop({
    required this.showBeams,
    required this.animate,
  });

  @override
  State<_PremiumBackdrop> createState() => _PremiumBackdropState();
}

class _PremiumBackdropState extends State<_PremiumBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 18.seconds);
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * math.pi * 2;
        return Stack(
          children: [
            // Electric cyan bloom — top right
            Positioned(
              top: -80 + math.sin(t) * 20,
              right: -60 + math.cos(t) * 14,
              child: _GlowOrb(
                size: 360,
                color: const Color(0xFF0090C8).withOpacity(0.50),
              ),
            ),
            // Deep ocean pool — bottom left
            Positioned(
              bottom: -100 + math.cos(t) * 22,
              left: -70 + math.sin(t) * 18,
              child: _GlowOrb(
                size: 400,
                color: const Color(0xFF0840A0).withOpacity(0.42),
              ),
            ),
            // Teal accent — top left drift
            Positioned(
              top: -50 + math.cos(t * 0.7) * 16,
              left: -30 + math.sin(t * 0.9) * 12,
              child: _GlowOrb(
                size: 280,
                color: const Color(0xFF0878A0).withOpacity(0.38),
              ),
            ),
            // Sky blue glow — bottom right
            Positioned(
              bottom: -70 + math.sin(t * 0.6) * 14,
              right: -50 + math.cos(t * 0.8) * 12,
              child: _GlowOrb(
                size: 300,
                color: const Color(0xFF1060C0).withOpacity(0.35),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  opacity: 0.06 + math.sin(t) * 0.012,
                  showBeams: widget.showBeams,
                  phase: t,
                ),
              ),
            ),
            // Lens vignette — clearly visible edge darkening
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.28),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double opacity;
  final bool showBeams;
  final double phase;

  const _GridPainter({
    required this.opacity,
    required this.showBeams,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sweepRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Diagonal ambient light sweep — visible lens-flare shading
    canvas.drawRect(
      sweepRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(opacity * 2.5),
            Colors.transparent,
            Colors.black.withOpacity(opacity * 2.2),
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(sweepRect),
    );

    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1;
    const gap = 34.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    if (showBeams) {
      final beamPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF1060A0).withOpacity(0),
            const Color(0xFF1060A0).withOpacity(0.32),
            const Color(0xFF1060A0).withOpacity(0),
          ],
        ).createShader(sweepRect)
        ..strokeWidth = 3.0;
      final y = (math.sin(phase) * 0.5 + 0.5) * size.height;
      canvas.drawLine(
          Offset(-40, y), Offset(size.width + 40, y - 140), beamPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.opacity != opacity ||
      oldDelegate.showBeams != showBeams ||
      oldDelegate.phase != phase;
}
