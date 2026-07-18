import 'package:flutter/material.dart';

/// Candy Jelly design tokens — the app's unified visual line (design
/// direction 04). Every screen draws from here so the look stays consistent:
/// a grape-purple ground, glossy "jelly" surfaces with a thick light rim and a
/// solid darker bevel below, and a bright saturated accent set.
class Candy {
  Candy._();

  // ── Grounds ────────────────────────────────────────────────────────────
  static const bgTop = Color(0xFF5B2AA6);
  static const bgMid = Color(0xFF3A1B6E);
  static const bgBottom = Color(0xFF22103F);
  static const surface = Color(0xFF6A34BE); // card / panel purple (top)
  static const surfaceLow = Color(0xFF4A228A); // card bottom

  static const ink = Colors.white;
  static const inkSoft = Color(0xFFE3D3FF);
  static const inkMuted = Color(0xFFB69BE0);

  // ── Jelly accents ──────────────────────────────────────────────────────
  static const grape = Color(0xFF7B3FD1);
  static const teal = Color(0xFF12B5A6);
  static const pink = Color(0xFFFF6EA6);
  static const tangerine = Color(0xFFFFB03A);
  static const blue = Color(0xFF3E7BE0);
  static const lime = Color(0xFF8CE05A);
  static const gold = Color(0xFFFFD84D);
  static const goldLow = Color(0xFFFFB020);

  static const bg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgMid, bgBottom],
    stops: [0.0, 0.45, 1.0],
  );

  /// A darker shade of [c], used for the solid "jelly bevel" beneath a surface.
  static Color bevel(Color c) => Color.lerp(c, Colors.black, 0.34)!;

  /// A lighter shade of [c], used for the glossy top of a jelly gradient.
  static Color glossy(Color c) => Color.lerp(c, Colors.white, 0.16)!;

  /// A vertical glossy gradient for a jelly surface of base color [c].
  static LinearGradient jellyFill(Color c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [glossy(c), c],
      );

  /// The signature jelly shadow: a solid darker edge directly below (no blur)
  /// that reads as depth, plus a soft ambient drop.
  static List<BoxShadow> jellyShadow(Color base, {double depth = 6}) => [
        BoxShadow(color: bevel(base), offset: Offset(0, depth), blurRadius: 0),
        BoxShadow(
          color: Colors.black.withOpacity(0.28),
          offset: Offset(0, depth + 4),
          blurRadius: 14,
        ),
      ];

  /// Standard thick light rim that outlines every jelly surface.
  static Border rim({double width = 3, double opacity = 0.38}) =>
      Border.all(color: Colors.white.withOpacity(opacity), width: width);
}
