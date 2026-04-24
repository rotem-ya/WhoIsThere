import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const secondary = Color(0xFFFF6584);
  static const accent = Color(0xFF43E97B);
  static const warning = Color(0xFFFFB347);
  static const background = Color(0xFFF8F9FF);
  static const darkBlue = Color(0xFF2D3561);
  static const surface = Color(0xFFFFFFFF);
  static const error = Color(0xFFE53E3E);

  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const secondaryGradient = LinearGradient(
    colors: [Color(0xFFFF6584), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF43E97B), Color(0xFF38F9D7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const boardBackground = Color(0xFFE8EAF6);
  static const pieceSlotEmpty = Color(0xFFD1D5F0);
  static const pieceSlotFilled = Color(0xFF43E97B);

  static const scorePlus = Color(0xFF43E97B);
  static const scoreMinus = Color(0xFFFF6584);
  static const scoreNeutral = Color(0xFF6C63FF);

  static const hostBadge = Color(0xFFFFB347);
  static const eliminatedOverlay = Color(0x99000000);
}
