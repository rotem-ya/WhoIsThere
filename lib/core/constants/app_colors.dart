import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFFD4AF37);
  static const primaryDark = Color(0xFF07101F);
  static const primaryLight = Color(0xFFFFE27A);
  static const secondary = Color(0xFF87CEEB);
  static const accent = Color(0xFF87CEEB);
  static const warning = Color(0xFFFFE27A);
  static const background = Color(0xFF07101F);
  static const darkBlue = Color(0xFF07101F);
  static const surface = Color(0xFFFFFFFF);
  static const vaultSurface = Color(0xFF0C1624);
  static const error = Color(0xFFE53E3E);

  static const backgroundTop = Color(0xFF07101F);
  static const backgroundBottom = Color(0xFF050A14);
  static const cardColor = Color(0xFFFFFBFF);
  static const primaryAction = primary;
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);

  static const pageBackground = LinearGradient(
    colors: [Color(0xFF07101F), Color(0xFF0E1E35), Color(0xFF050A14)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFFFFE27A), Color(0xFFD4AF37), Color(0xFFA1811A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const secondaryGradient = LinearGradient(
    colors: [Color(0xFF07101F), Color(0xFF0E1E35)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF87CEEB), Color(0xFF2FA7C9)],
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
