import 'package:flutter/material.dart';

class AppColors {
  // Candy Jelly line: gold primary, teal accent (was sky-blue).
  static const primary = Color(0xFFFFD84D);
  static const primaryDark = Color(0xFF22103F);
  static const primaryLight = Color(0xFFFFE27A);
  static const secondary = Color(0xFF12B5A6);
  static const accent = Color(0xFF12B5A6);
  static const warning = Color(0xFFFFE27A);
  static const background = Color(0xFF07101F);
  static const darkBlue = Color(0xFF07101F);
  static const surface = Color(0xFFFFFFFF);
  static const vaultSurface = Color(0xFF4A228A);
  static const error = Color(0xFFE53E3E);

  static const backgroundTop = Color(0xFF07101F);
  static const backgroundBottom = Color(0xFF050A14);
  static const cardColor = Color(0xFFFFFBFF);
  static const primaryAction = primary;
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);

  static const pageBackground = LinearGradient(
    colors: [Color(0xFF5B2AA6), Color(0xFF3A1B6E), Color(0xFF22103F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
  );

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFFFE27A), Color(0xFFD4AF37), Color(0xFFA1811A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const secondaryGradient = LinearGradient(
    colors: [Color(0xFF6A34BE), Color(0xFF4A228A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF12B5A6), Color(0xFF0B7E74)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [Color(0xFFFFE27A), Color(0xFFD4AF37), Color(0xFFA1811A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const boardBackground = Color(0xFF050A14);
  static const pieceSlotEmpty = Color(0xFF3B425A);
  static const pieceSlotFilled = Color(0xFF87CEEB);

  static const scorePlus = Color(0xFF22C55E);
  static const scoreMinus = Color(0xFFEF4444);
  static const scoreNeutral = Color(0xFFD4AF37);

  static const hostBadge = Color(0xFFD4AF37);
  static const eliminatedOverlay = Color(0x99000000);
}
