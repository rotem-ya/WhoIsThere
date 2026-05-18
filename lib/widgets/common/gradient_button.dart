import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import 'app_feedback.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final double? width;
  final double height;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.width,
    this.height = 56,
    this.icon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  void _onDown(_) => setState(() => _pressed = true);
  void _onUp(_) => setState(() => _pressed = false);
  void _onCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    // Press: 90 ms down, 140 ms up — no bounce.
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: _pressed
          ? const Duration(milliseconds: 90)
          : const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: enabled
              ? (widget.gradient ?? AppColors.primaryGradient)
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
          // Shadow compresses on press, expands on release.
          boxShadow: enabled
              ? _pressed
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.14),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.20),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: !enabled
                ? null
                : () {
                    AppFeedback.primary();
                    widget.onPressed?.call();
                  },
            onTapDown: enabled ? _onDown : null,
            onTapCancel: enabled ? _onCancel : null,
            onTapUp: enabled ? _onUp : null,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Shine pauses during press.
                if (enabled && !_pressed)
                  const _ButtonShine()
                      .animate(onPlay: (c) => c.repeat())
                      .slideX(begin: -1.4, end: 1.4, duration: 2200.ms),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // Entrance scale — easeOut, no bounce.
    ).animate().scale(
          begin: const Offset(0.96, 0.96),
          duration: 450.ms,
          curve: Curves.easeOut,
        );
  }
}

class _ButtonShine extends StatelessWidget {
  const _ButtonShine();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.34,
        heightFactor: 1,
        child: Transform.rotate(
          angle: -0.32,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0),
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
