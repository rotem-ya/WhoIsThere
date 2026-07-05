import 'package:flutter/material.dart';

enum FrameTier { free, basic, rare, premium }

/// A purely cosmetic ring drawn around a player's avatar. Frames are rendered in
/// code (no assets) from [colors] + [glow], so adding one is a single list entry.
class AvatarFrame {
  final String id;
  final String name;
  final int price;

  /// Ring gradient colours (swept around the circle). Empty = no ring ("none").
  final List<Color> colors;

  /// Soft outer glow in the ring's primary colour.
  final bool glow;

  /// Number of evenly-spaced "gem" studs around the ring (0 = none).
  final int studs;

  /// Draws a second thin inner ring with a small gap (a premium accent).
  final bool doubleRing;

  const AvatarFrame({
    required this.id,
    required this.name,
    required this.price,
    this.colors = const [],
    this.glow = false,
    this.studs = 0,
    this.doubleRing = false,
  });

  /// The "no frame" default everyone owns implicitly.
  bool get isNone => id == 'none' || colors.isEmpty;
  bool get isFree => price == 0;

  FrameTier get tier {
    if (price == 0) return FrameTier.free;
    if (price <= 150) return FrameTier.basic;
    if (price < 1000) return FrameTier.rare;
    return FrameTier.premium;
  }

  Color get accent => colors.isEmpty ? const Color(0xFF8090B0) : colors.first;
}

const kAvatarFrames = <AvatarFrame>[
  // ── חינמי (ברירת מחדל) ───────────────────────────────────────────────────────
  AvatarFrame(id: 'none', name: 'ללא מסגרת', price: 0),

  // ── בסיסי (50–150 מטבעות) ───────────────────────────────────────────────────
  AvatarFrame(
    id: 'bronze',
    name: 'ארד',
    price: 50,
    colors: [Color(0xFFCD7F32), Color(0xFF8C5A23)],
  ),
  AvatarFrame(
    id: 'silver',
    name: 'כסף',
    price: 70,
    colors: [Color(0xFFE0E0E0), Color(0xFF9AA0A8)],
  ),
  AvatarFrame(
    id: 'ocean',
    name: 'גלי ים',
    price: 90,
    colors: [Color(0xFF00BCD4), Color(0xFF0066A0)],
  ),
  AvatarFrame(
    id: 'forest',
    name: 'יער',
    price: 110,
    colors: [Color(0xFF4CAF50), Color(0xFF1B7A2E)],
  ),
  AvatarFrame(
    id: 'gold',
    name: 'זהב',
    price: 150,
    colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
  ),

  // ── נדיר (300–500 מטבעות) ───────────────────────────────────────────────────
  AvatarFrame(
    id: 'sunset',
    name: 'שקיעה',
    price: 300,
    colors: [Color(0xFFFF9A9E), Color(0xFFFF6A3D), Color(0xFFFFC371)],
    glow: true,
    studs: 8,
  ),
  AvatarFrame(
    id: 'ice',
    name: 'קרח',
    price: 360,
    colors: [Color(0xFF81D4FA), Color(0xFFE0FFFF), Color(0xFF29B6F6)],
    glow: true,
    studs: 8,
  ),
  AvatarFrame(
    id: 'fire',
    name: 'אש',
    price: 420,
    colors: [Color(0xFFFFD54F), Color(0xFFFF5722), Color(0xFFD32F2F)],
    glow: true,
    studs: 8,
  ),
  AvatarFrame(
    id: 'neon',
    name: 'נאון',
    price: 500,
    colors: [Color(0xFFFF00FF), Color(0xFF00FFFF), Color(0xFFFF00FF)],
    glow: true,
    studs: 10,
  ),

  // ── פרימיום (1000 מטבעות) ───────────────────────────────────────────────────
  AvatarFrame(
    id: 'royal',
    name: 'מלכותי',
    price: 1000,
    colors: [Color(0xFFFFD700), Color(0xFF8E2DE2), Color(0xFFFFD700)],
    glow: true,
    studs: 12,
    doubleRing: true,
  ),
  AvatarFrame(
    id: 'diamond',
    name: 'יהלום',
    price: 1000,
    colors: [Color(0xFFE0FFFF), Color(0xFF00E5FF), Color(0xFFFFFFFF)],
    glow: true,
    studs: 12,
    doubleRing: true,
  ),
  AvatarFrame(
    id: 'legend',
    name: 'אגדה',
    price: 1000,
    colors: [
      Color(0xFFFF0000),
      Color(0xFFFFD700),
      Color(0xFF00FF00),
      Color(0xFF00BFFF),
      Color(0xFFFF00FF),
    ],
    glow: true,
    studs: 16,
    doubleRing: true,
  ),
];

AvatarFrame frameFor(String? id) {
  if (id == null) return kAvatarFrames.first;
  for (final f in kAvatarFrames) {
    if (f.id == id) return f;
  }
  return kAvatarFrames.first;
}
