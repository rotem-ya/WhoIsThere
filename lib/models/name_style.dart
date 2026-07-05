import 'package:flutter/material.dart';

enum NameStyleTier { free, basic, rare, premium }

/// A purely cosmetic colour/gradient applied to a player's name label.
/// Rendered in code from [colors]: one colour = solid, several = gradient.
class NameStyle {
  final String id;
  final String name;
  final int price;

  /// Empty = default (inherit the surrounding style). One = solid colour.
  /// Several = horizontal gradient (rendered via ShaderMask).
  final List<Color> colors;

  const NameStyle({
    required this.id,
    required this.name,
    required this.price,
    this.colors = const [],
  });

  bool get isNone => id == 'none' || colors.isEmpty;
  bool get isFree => price == 0;
  bool get isGradient => colors.length > 1;

  NameStyleTier get tier {
    if (price == 0) return NameStyleTier.free;
    if (price <= 150) return NameStyleTier.basic;
    if (price < 1000) return NameStyleTier.rare;
    return NameStyleTier.premium;
  }

  Color get accent => colors.isEmpty ? const Color(0xFF8090B0) : colors.first;
}

const kNameStyles = <NameStyle>[
  // ── חינמי (ברירת מחדל) ───────────────────────────────────────────────────────
  NameStyle(id: 'none', name: 'רגיל', price: 0),

  // ── בסיסי (50–150) — צבע אחיד ───────────────────────────────────────────────
  NameStyle(id: 'aqua',   name: 'תכלת',   price: 50,  colors: [Color(0xFF4FC3F7)]),
  NameStyle(id: 'mint',   name: 'מנטה',   price: 70,  colors: [Color(0xFF4DD0A0)]),
  NameStyle(id: 'coral',  name: 'אלמוג',  price: 90,  colors: [Color(0xFFFF8A65)]),
  NameStyle(id: 'rose',   name: 'ורד',    price: 110, colors: [Color(0xFFFF7AA2)]),
  NameStyle(id: 'gold',   name: 'זהב',    price: 150, colors: [Color(0xFFFFD54F)]),

  // ── נדיר (300–500) — גרדיאנט ─────────────────────────────────────────────────
  NameStyle(id: 'ocean',  name: 'אוקיינוס', price: 300, colors: [Color(0xFF00E5FF), Color(0xFF2979FF)]),
  NameStyle(id: 'sunset', name: 'שקיעה',    price: 360, colors: [Color(0xFFFFD54F), Color(0xFFFF5722)]),
  NameStyle(id: 'lime',   name: 'ליים',     price: 420, colors: [Color(0xFFB2FF59), Color(0xFF00C853)]),
  NameStyle(id: 'neon',   name: 'נאון',     price: 500, colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)]),

  // ── פרימיום (1000) — גרדיאנט עשיר ────────────────────────────────────────────
  NameStyle(id: 'royal',   name: 'מלכותי', price: 1000, colors: [Color(0xFFFFD700), Color(0xFF8E2DE2)]),
  NameStyle(id: 'fire',    name: 'אש',      price: 1000, colors: [Color(0xFFFFE082), Color(0xFFFF5722), Color(0xFFD32F2F)]),
  NameStyle(id: 'rainbow', name: 'קשת',     price: 1000, colors: [
    Color(0xFFFF0000), Color(0xFFFFD700), Color(0xFF00FF00), Color(0xFF00BFFF), Color(0xFFFF00FF),
  ]),
];

NameStyle nameStyleFor(String? id) {
  if (id == null) return kNameStyles.first;
  for (final s in kNameStyles) {
    if (s.id == id) return s;
  }
  return kNameStyles.first;
}
