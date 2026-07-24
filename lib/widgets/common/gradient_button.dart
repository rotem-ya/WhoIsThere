import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/candy_theme.dart';
import 'app_feedback.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;

  /// Async tap handler. When provided, the button shows a spinner in place of
  /// its label while the future runs, and ignores further taps until it
  /// settles — so callers don't have to thread their own loading flag.
  final Future<void> Function()? onPressedAsync;

  /// Force the loading spinner on (for callers that manage their own state).
  final bool loading;
  final LinearGradient? gradient;
  final double? width;
  final double height;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.onPressedAsync,
    this.loading = false,
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
  bool _busy = false;

  void _onDown(_) => setState(() => _pressed = true);
  void _onUp(_) => setState(() => _pressed = false);
  void _onCancel() => setState(() => _pressed = false);

  bool get _loading => widget.loading || _busy;

  Future<void> _handleTap() async {
    AppFeedback.primary();
    if (widget.onPressedAsync != null) {
      if (_busy) return;
      setState(() => _busy = true);
      try {
        await widget.onPressedAsync!.call();
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // "Active" look (colored fill + shadow) whenever there's a handler, even
    // while loading; taps only fire when not mid-flight.
    final hasHandler =
        widget.onPressed != null || widget.onPressedAsync != null;
    final enabled = hasHandler && !_loading;
    final active = hasHandler; // keeps the color during the loading spinner

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
          gradient: active
              ? (widget.gradient ?? Candy.jellyFill(Candy.tangerine))
              : const LinearGradient(colors: [Colors.grey, Colors.grey]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
          // Shadow compresses on press, expands on release.
          boxShadow: active
              ? _pressed
                  ? [
                      BoxShadow(
                        color: Candy.tangerine.withOpacity(0.14),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Candy.tangerine.withOpacity(0.35),
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
            onTap: !enabled ? null : _handleTap,
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
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
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
