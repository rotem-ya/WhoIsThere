import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Single source of truth for the dark vault visual identity.
///
/// Usage: import 'package:whois_there/core/theme/app_styles.dart';
/// Then reference AppStyles.backgroundGradient, AppStyles.glassCard(), etc.
abstract class AppStyles {
  // ── Core Palette ──────────────────────────────────────────────────────

  /// Background top — dark vault navy
  static const Color navyTop = AppColors.background;

  /// Background mid — dark vault mid
  static const Color navyMid = Color(0xFF0D2244);

  /// Background bottom — deep vault black-navy
  static const Color cyanBottom = AppColors.backgroundBottom;

  /// Primary action color — "Banana Yellow"
  static const Color bananaYellow = Color(0xFFFFE14D);

  /// Highlight / glow — electric cyan
  static const Color cyanGlow = Color(0xFF00F2FF);

  static const Color white = Colors.white;
  static const Color darkText = AppColors.background;
  static const Color errorRed = AppColors.error;
  static const Color successGreen = AppColors.success;
  static const Color warningAmber = Color(0xFFFFA726);

  // ── Gradients ─────────────────────────────────────────────────────────

  /// Full-screen background: dark vault top → deep black-navy bottom.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navyTop, navyMid, Color(0xFF071540), Color(0xFF040A18)],
    stops: [0.0, 0.40, 0.75, 1.0],
  );

  /// Banana action button gradient (top-highlight → mid-yellow → bottom-shadow).
  static const LinearGradient bananaGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFEF70), bananaYellow, Color(0xFFE6C800)],
    stops: [0.0, 0.50, 1.0],
  );

  /// Cyan glow gradient for secondary accents.
  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyanGlow, cyanBottom],
  );

  /// Subtle vault card gradient.
  static const LinearGradient navyCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E1E35), Color(0xFF07101F)],
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
