import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextStyle get titleLight => GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        height: 1.05,
        color: AppColors.surface,
      );

  static TextStyle get titleDark => titleLight.copyWith(
        color: Colors.white,
      );

  static TextStyle get subtitleLight => GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.surface.withOpacity(0.74),
      );

  static TextStyle get subtitleDark => subtitleLight.copyWith(
        color: Colors.white.withOpacity(0.65),
      );

  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: Colors.white.withOpacity(0.85),
      );

  static TextStyle get button => GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        height: 1,
        color: AppColors.surface,
      );
}
