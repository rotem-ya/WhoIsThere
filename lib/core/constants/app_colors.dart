import 'package:flutter/material.dart';

class AppColors {
  // Arcade redesign palette: controlled, bold, and consistent.
  static const primary = Color(0xFF5B3DF5);
  static const primaryDark = Color(0xFF24145F);
  static const primaryLight = Color(0xFF8C7BFF);
  static const secondary = Color(0xFFFF4F7B);
  static const accent = Color(0xFF22D6C7);
  static const warning = Color(0xFFFFC247);
  static const background = Color(0xFF11183B);
  static const darkBlue = Color(0xFF18224B);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFE53E3E);

  static const backgroundTop = Color(0xFF11183B);
  static const backgroundBottom = Color(0xFF24145F);
  static const cardColor = Color(0xFFFFFBFF);
  static const primaryAction = primary;
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);

  static const pageBackground = LinearGradient(
    colors: [backgroundTop, Color(0xFF26358C), backgroundBottom],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF31D7F4), Color(0xFF6B45FF), Color(0xFFFF4F9A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const secondaryGradient = LinearGradient(
    colors: [Color(0xFFFF4F7B), Color(0xFFFF8B3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF20E5A5), Color(0xFF20C9F4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFD95A), Color(0xFFFF9F1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const boardBackground = Color(0xFF171F4F);
  static const pieceSlotEmpty = Color(0xFFB9B4FF);
  static const pieceSlotFilled = Color(0xFF22D6C7);

  static const scorePlus = Color(0xFF20E5A5);
  static const scoreMinus = Color(0xFFFF4F7B);
  static const scoreNeutral = Color(0xFF6B45FF);

  static const hostBadge = Color(0xFFFFC247);
  static const eliminatedOverlay = Color(0x99000000);
}
