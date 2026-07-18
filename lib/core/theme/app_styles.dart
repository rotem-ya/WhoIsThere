import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'candy_theme.dart';

/// Single source of truth for the dark vault visual identity.
///
/// Usage: import 'package:whois_there/core/theme/app_styles.dart';
/// Then reference AppStyles.backgroundGradient, AppStyles.glassCard(), etc.
abstract class AppStyles {
  // ── Core Palette ──────────────────────────────────────────────────────

  /// Background top — Candy grape purple
  static const Color navyTop = Candy.bgTop;

  /// Background mid — deep grape
  static const Color navyMid = Candy.bgMid;

  /// Background bottom — deep purple
  static const Color cyanBottom = Candy.bgBottom;

  /// Primary action color — Candy gold
  static const Color bananaYellow = Candy.gold;

  /// Highlight / glow — Candy teal
  static const Color cyanGlow = Candy.teal;

  static const Color white = Colors.white;
  static const Color darkText = AppColors.background;
  static const Color errorRed = AppColors.error;
  static const Color successGreen = AppColors.success;
  static const Color warningAmber = Candy.tangerine;

  // ── Gradients ─────────────────────────────────────────────────────────

  /// Full-screen background: the unified Candy grape ground.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Candy.bgTop, Candy.bgMid, Color(0xFF2A1550), Candy.bgBottom],
    stops: [0.0, 0.40, 0.75, 1.0],
  );

  /// Candy gold action button gradient (glossy top → gold → deep gold).
  static const LinearGradient bananaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE98A), Candy.gold, Candy.goldLow],
    stops: [0.0, 0.50, 1.0],
  );

  /// Teal glow gradient for secondary accents.
  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyanGlow, cyanBottom],
  );

  /// Subtle Candy jelly card gradient.
  static const LinearGradient navyCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Candy.surface, Candy.surfaceLow],
  );

  // ── Decorations ───────────────────────────────────────────────────────

  /// Frosted-glass panel — white overlay on the background gradient.
  static BoxDecoration glassCard({double radius = 20, double opacity = 0.18}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(opacity),
          Colors.white.withOpacity(opacity * 0.35),
        ],
      ),
      border: Border.all(
        color: Colors.white.withOpacity(0.32),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: navyTop.withOpacity(0.28),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.10),
          blurRadius: 1,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  /// Glossy banana-yellow action button.
  static BoxDecoration glossyButton({double radius = 16}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: bananaGradient,
      boxShadow: [
        BoxShadow(
          color: bananaYellow.withOpacity(0.55),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.18),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// White elevated card (for content that needs contrast).
  static BoxDecoration elevatedCard({double radius = 20}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: navyTop.withOpacity(0.20),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Cyan glow box shadows — use on highlighted / active elements.
  static List<BoxShadow> cyanGlowShadow({double intensity = 1.0}) => [
        BoxShadow(
          color: cyanGlow.withOpacity(0.45 * intensity),
          blurRadius: 20,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: cyanBottom.withOpacity(0.25 * intensity),
          blurRadius: 40,
          spreadRadius: 4,
        ),
      ];

  /// Banana-yellow glow box shadows.
  static List<BoxShadow> bananaGlowShadow({double intensity = 1.0}) => [
        BoxShadow(
          color: bananaYellow.withOpacity(0.50 * intensity),
          blurRadius: 18,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: bananaYellow.withOpacity(0.20 * intensity),
          blurRadius: 36,
          spreadRadius: 3,
        ),
      ];

  // ── Text Styles ───────────────────────────────────────────────────────

  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: white,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: white,
    height: 1.2,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: white,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: white,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: white,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: white,
  );

  /// Label for banana-yellow buttons — dark text for contrast on yellow.
  static const TextStyle labelButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: darkText,
    letterSpacing: 0.3,
  );

  /// Cyan glow label — for active states, highlights, codes.
  static const TextStyle cyanLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: cyanGlow,
    letterSpacing: 0.5,
  );

  static const TextStyle cyanLabelLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: cyanGlow,
    letterSpacing: 0.3,
  );
}
