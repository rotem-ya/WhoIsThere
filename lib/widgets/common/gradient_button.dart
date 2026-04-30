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

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _pressed ? 0.965 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Container(
        width: widget.width ?? double.infinity,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: enabled
              ? (widget.gradient ?? AppColors.primaryGradient)
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
          boxShadow: enabled
              ? [
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
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapCancel:
                enabled ? () => setState(() => _pressed = false) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (enabled)
                  const _ButtonShine()
                      .animate(onPlay: (controller) => controller.repeat())
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
      ).animate().scale(
            begin: const Offset(0.96, 0.96),
            duration: 450.ms,
            curve: Curves.easeOutBack,
          ),
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
                  Colors.white.withOpacity(0.20),
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
