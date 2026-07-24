import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/candy_theme.dart';

/// A friendly, on-brand empty state: a soft glowing disc with a big glyph, a
/// bold title, a muted line, and an optional call to action. Replaces bare
/// "there's nothing here" text so empty screens feel designed rather than
/// broken. The glyph floats gently and fades in on first show.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accent;
  final EdgeInsets padding;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.accent = Candy.teal,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing disc + glyph, floating gently.
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withOpacity(0.28),
                  accent.withOpacity(0.06),
                ],
              ),
              border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.22),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 42)),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: -4, end: 5, duration: 2200.ms, curve: Curves.easeInOut),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 14.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Candy.bgBottom,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              child: Text(actionLabel!, textDirection: TextDirection.rtl),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 360.ms, curve: Curves.easeOut)
        .scaleXY(begin: 0.94, end: 1.0, duration: 360.ms, curve: Curves.easeOut);
  }
}
