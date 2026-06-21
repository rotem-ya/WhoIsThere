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
  // ── חינמי — סט פתיחה נדיב וצבעוני ────────────────────────────────────────────
  AvatarChoice(id: 'auto', name: 'אוטומטי', price: 0, emoji: '🎲', colors: [Color(0xFF334155), Color(0xFF1E293B)]),
  AvatarChoice(id: 'cool',   name: 'קולי',    price: 0, emoji: '😎', colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)]),
  AvatarChoice(id: 'fox',    name: 'שועל',    price: 0, emoji: '🦊', colors: [Color(0xFFFF8A65), Color(0xFFBF360C)]),
  AvatarChoice(id: 'cat',    name: 'חתול',    price: 0, emoji: '🐱', colors: [Color(0xFF9575CD), Color(0xFF4527A0)]),
  AvatarChoice(id: 'dog',    name: 'כלב',     price: 0, emoji: '🐶', colors: [Color(0xFFA1887F), Color(0xFF4E342E)]),
  AvatarChoice(id: 'robot',  name: 'רובוט',   price: 0, emoji: '🤖', colors: [Color(0xFF4DD0E1), Color(0xFF00838F)]),
  AvatarChoice(id: 'alien',  name: 'חייזר',   price: 0, emoji: '👾', colors: [Color(0xFF81C784), Color(0xFF2E7D32)]),
  AvatarChoice(id: 'frog',   name: 'צפרדע',   price: 0, emoji: '🐸', colors: [Color(0xFF9CCC65), Color(0xFF33691E)]),
  AvatarChoice(id: 'penguin', name: 'פינגווין', price: 0, emoji: '🐧', colors: [Color(0xFF90CAF9), Color(0xFF1565C0)]),
  AvatarChoice(id: 'monkey', name: 'קוף',     price: 0, emoji: '🐵', colors: [Color(0xFFBCAAA4), Color(0xFF5D4037)]),

  // ── בסיסי (50–150) — חיות ───────────────────────────────────────────────────
  AvatarChoice(id: 'lion',    name: 'אריה',    price: 50,  emoji: '🦁', colors: [Color(0xFFFFD54F), Color(0xFFF57F17)]),
  AvatarChoice(id: 'tiger',   name: 'נמר',     price: 50,  emoji: '🐯', colors: [Color(0xFFFFB74D), Color(0xFFE65100)]),
  AvatarChoice(id: 'bear',    name: 'דוב',     price: 60,  emoji: '🐻', colors: [Color(0xFFA1887F), Color(0xFF3E2723)]),
  AvatarChoice(id: 'panda',   name: 'פנדה',    price: 60,  emoji: '🐼', colors: [Color(0xFFE0E0E0), Color(0xFF616161)]),
  AvatarChoice(id: 'koala',   name: 'קואלה',   price: 70,  emoji: '🐨', colors: [Color(0xFFB0BEC5), Color(0xFF455A64)]),
  AvatarChoice(id: 'wolf',    name: 'זאב',     price: 70,  emoji: '🐺', colors: [Color(0xFF90A4AE), Color(0xFF37474F)]),
  AvatarChoice(id: 'rabbit',  name: 'ארנב',    price: 80,  emoji: '🐰', colors: [Color(0xFFF8BBD0), Color(0xFFAD1457)]),
  AvatarChoice(id: 'hamster', name: 'אוגר',    price: 80,  emoji: '🐹', colors: [Color(0xFFFFCC80), Color(0xFFEF6C00)]),
  AvatarChoice(id: 'pig',     name: 'חזיר',    price: 90,  emoji: '🐷', colors: [Color(0xFFF48FB1), Color(0xFFC2185B)]),
  AvatarChoice(id: 'cow',     name: 'פרה',     price: 90,  emoji: '🐮', colors: [Color(0xFFD7CCC8), Color(0xFF5D4037)]),
  AvatarChoice(id: 'chick',   name: 'אפרוח',   price: 100, emoji: '🐥', colors: [Color(0xFFFFF176), Color(0xFFF9A825)]),
  AvatarChoice(id: 'owl',     name: 'ינשוף',   price: 100, emoji: '🦉', colors: [Color(0xFFA1887F), Color(0xFF4E342E)]),
  AvatarChoice(id: 'hedgehog', name: 'קיפוד',  price: 110, emoji: '🦔', colors: [Color(0xFFBCAAA4), Color(0xFF4E342E)]),
  AvatarChoice(id: 'raccoon', name: 'דביבון',  price: 110, emoji: '🦝', colors: [Color(0xFF90A4AE), Color(0xFF263238)]),
  AvatarChoice(id: 'octopus', name: 'תמנון',   price: 120, emoji: '🐙', colors: [Color(0xFFF06292), Color(0xFFAD1457)]),
  AvatarChoice(id: 'turtle',  name: 'צב',      price: 120, emoji: '🐢', colors: [Color(0xFF81C784), Color(0xFF1B5E20)]),
  AvatarChoice(id: 'butterfly', name: 'פרפר',  price: 130, emoji: '🦋', colors: [Color(0xFF80DEEA), Color(0xFF6A1B9A)]),
  AvatarChoice(id: 'dolphin', name: 'דולפין',  price: 130, emoji: '🐬', colors: [Color(0xFF4FC3F7), Color(0xFF0277BD)]),
  AvatarChoice(id: 'shark',   name: 'כריש',    price: 140, emoji: '🦈', colors: [Color(0xFF4FC3F7), Color(0xFF01579B)]),
  AvatarChoice(id: 'deer',    name: 'צבי',     price: 150, emoji: '🦌', colors: [Color(0xFFD7A86E), Color(0xFF6D4C2B)]),

  // ── נדיר (300–500) — חיות אקזוטיות + דמויות משחק ─────────────────────────────
  AvatarChoice(id: 'unicorn', name: 'חד-קרן',  price: 300, emoji: '🦄', colors: [Color(0xFFFF80AB), Color(0xFF7C4DFF)]),
  AvatarChoice(id: 'whale',   name: 'לוויתן',  price: 300, emoji: '🐳', colors: [Color(0xFF4FC3F7), Color(0xFF01579B)]),
  AvatarChoice(id: 'peacock', name: 'טווס',    price: 320, emoji: '🦚', colors: [Color(0xFF26C6DA), Color(0xFF00695C)]),
  AvatarChoice(id: 'parrot',  name: 'תוכי',    price: 320, emoji: '🦜', colors: [Color(0xFF66BB6A), Color(0xFFD84315)]),
  AvatarChoice(id: 'ninja',   name: 'נינג׳ה',  price: 360, emoji: '🥷', colors: [Color(0xFF455A64), Color(0xFF0D0D0D)]),
  AvatarChoice(id: 'wizard',  name: 'קוסם',    price: 360, emoji: '🧙', colors: [Color(0xFF7E57C2), Color(0xFF311B92)]),
  AvatarChoice(id: 'superhero', name: 'גיבור-על', price: 400, emoji: '🦸', colors: [Color(0xFF42A5F5), Color(0xFFC62828)]),
  AvatarChoice(id: 'villain', name: 'נבל-על',  price: 400, emoji: '🦹', colors: [Color(0xFF7E57C2), Color(0xFF1A0033)]),
  AvatarChoice(id: 'ghost',   name: 'רוח',     price: 420, emoji: '👻', colors: [Color(0xFFE1BEE7), Color(0xFF4A148C)]),
  AvatarChoice(id: 'zombie',  name: 'זומבי',   price: 420, emoji: '🧟', colors: [Color(0xFF9CCC65), Color(0xFF33691E)]),
  AvatarChoice(id: 'clown',   name: 'ליצן',    price: 440, emoji: '🤡', colors: [Color(0xFFFF8A80), Color(0xFFD500F9)]),
  AvatarChoice(id: 'detective', name: 'בלש',   price: 440, emoji: '🕵️', colors: [Color(0xFF8D6E63), Color(0xFF3E2723)]),
  AvatarChoice(id: 'eagle',   name: 'נשר',     price: 460, emoji: '🦅', colors: [Color(0xFFA1887F), Color(0xFF3E2723)]),
  AvatarChoice(id: 'genie',   name: 'ג׳יני',   price: 480, emoji: '🧞', colors: [Color(0xFF26C6DA), Color(0xFF6A1B9A)]),
  AvatarChoice(id: 'dragon',  name: 'דרקון',   price: 500, emoji: '🐉', colors: [Color(0xFF66BB6A), Color(0xFF1B5E20)]),
  AvatarChoice(id: 'trex',    name: 'טי-רקס',  price: 500, emoji: '🦖', colors: [Color(0xFF9CCC65), Color(0xFF2E5022)]),

  // ── פרימיום (1000) — אגדיים ───────────────────────────────────────────────────
  AvatarChoice(id: 'king',    name: 'מלך',     price: 1000, emoji: '👑', colors: [Color(0xFFFFE082), Color(0xFFC9A227)]),
  AvatarChoice(id: 'fire',    name: 'להבה',    price: 1000, emoji: '🔥', colors: [Color(0xFFFFD54F), Color(0xFFD84315)]),
  AvatarChoice(id: 'star',    name: 'כוכב-על', price: 1000, emoji: '🌟', colors: [Color(0xFFFFF59D), Color(0xFFF9A825)]),
  AvatarChoice(id: 'bolt',    name: 'ברק',     price: 1000, emoji: '⚡', colors: [Color(0xFF80D8FF), Color(0xFF2962FF)]),
  AvatarChoice(id: 'rainbow', name: 'קשת',     price: 1000, emoji: '🌈', colors: [Color(0xFFFF4081), Color(0xFF00E5FF)]),
  AvatarChoice(id: 'diamond_av', name: 'יהלום', price: 1000, emoji: '💎', colors: [Color(0xFFE0FFFF), Color(0xFF00B8D4)]),
  AvatarChoice(id: 'cyborg',  name: 'סייבורג', price: 1000, emoji: '🦾', colors: [Color(0xFF90A4AE), Color(0xFF263238)]),
  AvatarChoice(id: 'joker',   name: 'ג׳וקר',   price: 1000, emoji: '🃏', colors: [Color(0xFFFF4081), Color(0xFF1A0033)]),
];

AvatarChoice avatarChoiceFor(String? id) {
  if (id == null) return kAvatarChoices.first;
  for (final a in kAvatarChoices) {
    if (a.id == id) return a;
  }
  return kAvatarChoices.first;
}
