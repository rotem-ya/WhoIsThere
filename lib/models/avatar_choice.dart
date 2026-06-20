import 'package:flutter/material.dart';

enum AvatarTier { free, basic, rare, premium }

/// A chosen "cool" avatar face: an emoji on a coloured gradient disc. Replaces
/// the auto-generated face from avatar_util when equipped. Rendered in code
/// (no assets) so adding one is a single catalog entry.
class AvatarChoice {
  final String id;
  final String name;
  final int price;
  final String emoji;

  /// Disc background gradient (1 colour = solid).
  final List<Color> colors;

  const AvatarChoice({
    required this.id,
    required this.name,
    required this.price,
    required this.emoji,
    this.colors = const [Color(0xFF1B3A5B)],
  });

  /// 'auto' = use the deterministic generated face (avatar_util), not a choice.
  bool get isAuto => id == 'auto';
  bool get isFree => price == 0;

  AvatarTier get tier {
    if (price == 0) return AvatarTier.free;
    if (price <= 150) return AvatarTier.basic;
    if (price < 1000) return AvatarTier.rare;
    return AvatarTier.premium;
  }

  Color get accent => colors.isEmpty ? const Color(0xFF4472C8) : colors.first;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors.length == 1 ? [colors.first, colors.first] : colors,
      );
}

const kAvatarChoices = <AvatarChoice>[
  // ── חינמי — סט פתיחה נדיב ─────────────────────────────────────────────────────
  AvatarChoice(id: 'auto', name: 'אוטומטי', price: 0, emoji: '🎲', colors: [Color(0xFF334155), Color(0xFF1E293B)]),
  AvatarChoice(id: 'cool',   name: 'קולי',    price: 0, emoji: '😎', colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]),
  AvatarChoice(id: 'fox',    name: 'שועל',    price: 0, emoji: '🦊', colors: [Color(0xFFFF8A65), Color(0xFFBF360C)]),
  AvatarChoice(id: 'cat',    name: 'חתול',    price: 0, emoji: '🐱', colors: [Color(0xFF9575CD), Color(0xFF4527A0)]),
  AvatarChoice(id: 'robot',  name: 'רובוט',   price: 0, emoji: '🤖', colors: [Color(0xFF4DD0E1), Color(0xFF00838F)]),
  AvatarChoice(id: 'alien',  name: 'חייזר',   price: 0, emoji: '👾', colors: [Color(0xFF81C784), Color(0xFF2E7D32)]),

  // ── בסיסי (50–150) ─────────────────────────────────────────────────────────
  AvatarChoice(id: 'lion',    name: 'אריה',    price: 50,  emoji: '🦁', colors: [Color(0xFFFFD54F), Color(0xFFF57F17)]),
  AvatarChoice(id: 'tiger',   name: 'נמר',     price: 70,  emoji: '🐯', colors: [Color(0xFFFFB74D), Color(0xFFE65100)]),
  AvatarChoice(id: 'wolf',    name: 'זאב',     price: 90,  emoji: '🐺', colors: [Color(0xFF90A4AE), Color(0xFF37474F)]),
  AvatarChoice(id: 'panda',   name: 'פנדה',    price: 110, emoji: '🐼', colors: [Color(0xFFE0E0E0), Color(0xFF616161)]),
  AvatarChoice(id: 'octopus', name: 'תמנון',   price: 130, emoji: '🐙', colors: [Color(0xFFF06292), Color(0xFFAD1457)]),
  AvatarChoice(id: 'shark',   name: 'כריש',    price: 150, emoji: '🦈', colors: [Color(0xFF4FC3F7), Color(0xFF01579B)]),

  // ── נדיר (300–500) ─────────────────────────────────────────────────────────
  AvatarChoice(id: 'unicorn', name: 'חד-קרן',  price: 300, emoji: '🦄', colors: [Color(0xFFFF80AB), Color(0xFF7C4DFF)]),
  AvatarChoice(id: 'ninja',   name: 'נינג׳ה',  price: 360, emoji: '🥷', colors: [Color(0xFF455A64), Color(0xFF0D0D0D)]),
  AvatarChoice(id: 'eagle',   name: 'נשר',     price: 420, emoji: '🦅', colors: [Color(0xFFA1887F), Color(0xFF3E2723)]),
  AvatarChoice(id: 'dragon',  name: 'דרקון',   price: 500, emoji: '🐉', colors: [Color(0xFF66BB6A), Color(0xFF1B5E20)]),

  // ── פרימיום (1000) ───────────────────────────────────────────────────────────
  AvatarChoice(id: 'king',    name: 'מלך',     price: 1000, emoji: '👑', colors: [Color(0xFFFFE082), Color(0xFFC9A227)]),
  AvatarChoice(id: 'fire',    name: 'להבה',    price: 1000, emoji: '🔥', colors: [Color(0xFFFFD54F), Color(0xFFD84315)]),
  AvatarChoice(id: 'star',    name: 'כוכב-על', price: 1000, emoji: '🌟', colors: [Color(0xFFFFF59D), Color(0xFFF9A825)]),
  AvatarChoice(id: 'bolt',    name: 'ברק',     price: 1000, emoji: '⚡', colors: [Color(0xFF80D8FF), Color(0xFF2962FF)]),
];

AvatarChoice avatarChoiceFor(String? id) {
  if (id == null) return kAvatarChoices.first;
  for (final a in kAvatarChoices) {
    if (a.id == id) return a;
  }
  return kAvatarChoices.first;
}
