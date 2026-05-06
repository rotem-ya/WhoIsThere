import 'package:flutter/material.dart';

class VaultStyle {
  const VaultStyle._();

  static const navyBg = Color(0xFF07101F);
  static const navyBlack = Color(0xFF050A14);
  static const gold = Color(0xFFD4AF37);
  static const goldDark = Color(0xFFA1811A);
  static const cyan = Color(0xFF87CEEB);
  static const softWhite = Color(0xFFF2F4F8);

  static BoxDecoration glassPanel({double radius = 24, double opacity = 0.72}) {
    return BoxDecoration(
      color: navyBg.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: gold.withOpacity(0.34), width: 1.1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.34),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static const metadata = TextStyle(
    fontFamily: 'Assistant',
    fontSize: 16,
    color: Colors.white70,
    fontWeight: FontWeight.w700,
  );

  static const mainTitle = TextStyle(
    fontFamily: 'Assistant',
    fontSize: 32,
    color: gold,
    fontWeight: FontWeight.w900,
    height: 1.0,
  );
}
