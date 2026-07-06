import 'package:flutter/material.dart';

enum WinEffectTier { free, basic, rare, premium }

/// How particles travel — the motion is the main thing that makes effects feel
/// distinct (not just colour).
enum WinEffectMotion { fall, rise, burst }

/// Particle shape (ignored when [WinEffect.emoji] is set).
enum WinEffectShape { rect, circle, ring }

/// A celebratory particle effect shown on the win screen for the winner's
/// equipped effect. Rendered in code (no assets) by [WinEffectOverlay].
class WinEffect {
  final String id;
  final String name;
  final int price;

  /// Particle palette (shape particles, or a glow tint for emoji).
  final List<Color> colors;

  /// When set, particles are this emoji instead of coloured shapes.
  final String? emoji;

  final WinEffectMotion motion;
  final WinEffectShape shape;

  /// Hidden from the store when false (still renders if already equipped).
  final bool active;

  const WinEffect({
    required this.id,
    required this.name,
    required this.price,
    this.colors = const [],
    this.emoji,
    this.motion = WinEffectMotion.fall,
    this.shape = WinEffectShape.rect,
    this.active = true,
  });

  bool get isNone => id == 'none';
  bool get isFree => price == 0;

  WinEffectTier get tier {
    if (price == 0) return WinEffectTier.free;
    if (price <= 150) return WinEffectTier.basic;
    if (price < 1000) return WinEffectTier.rare;
    return WinEffectTier.premium;
  }

  Color get accent => colors.isEmpty ? const Color(0xFFD4AF37) : colors.first;
}

const kWinEffects = <WinEffect>[
  // ── חינמי ─────────────────────────────────────────────────────────────────
  WinEffect(id: 'none', name: 'ללא', price: 0),

  // ── בסיסי (50–150) — חלקיקי צבע ──────────────────────────────────────────────
  WinEffect(
    id: 'confetti',
    name: 'קונפטי',
    price: 50,
    motion: WinEffectMotion.fall,
    shape: WinEffectShape.rect,
    colors: [
      Color(0xFFFF4081), Color(0xFF40C4FF), Color(0xFFFFD740),
      Color(0xFF69F0AE), Color(0xFFFF6E40),
    ],
  ),
  WinEffect(
    id: 'gold_shower',
    name: 'גשם זהב',
    price: 100,
    motion: WinEffectMotion.fall,
    shape: WinEffectShape.circle,
    colors: [Color(0xFFFFE082), Color(0xFFFFD700), Color(0xFFC9A227)],
  ),
  WinEffect(
    id: 'bubbles',
    name: 'בועות',
    price: 150,
    motion: WinEffectMotion.rise,
    shape: WinEffectShape.ring,
    colors: [Color(0xFF81D4FA), Color(0xFFE1F5FE), Color(0xFF4FC3F7)],
  ),

  // ── נדיר (300–500) — אימוג'י + תנועה ─────────────────────────────────────────
  WinEffect(
    id: 'stars',
    name: 'כוכבים',
    price: 300,
    motion: WinEffectMotion.fall,
    colors: [Color(0xFFFFD740)],
    emoji: '⭐',
  ),
  WinEffect(
    id: 'hearts',
    name: 'לבבות',
    price: 400,
    motion: WinEffectMotion.rise,
    colors: [Color(0xFFFF5A8A)],
    emoji: '❤️',
  ),
  WinEffect(
    id: 'party',
    name: 'מסיבה',
    price: 500,
    motion: WinEffectMotion.burst,
    colors: [Color(0xFFFFD740)],
    emoji: '🎉',
  ),

  // ── פרימיום (1000) ───────────────────────────────────────────────────────────
  WinEffect(
    id: 'fireworks',
    name: 'זיקוקים',
    price: 1000,
    motion: WinEffectMotion.burst,
    shape: WinEffectShape.circle,
    colors: [
      Color(0xFFFF1744), Color(0xFFFFD740), Color(0xFF18FFFF),
      Color(0xFF76FF03), Color(0xFFE040FB),
    ],
  ),
  WinEffect(
    id: 'crown',
    name: 'כתר מלכים',
    price: 1000,
    motion: WinEffectMotion.fall,
    colors: [Color(0xFFFFD700)],
    emoji: '👑',
  ),
  WinEffect(
    id: 'rainbow_confetti',
    name: 'קונפטי קשת',
    price: 1000,
    motion: WinEffectMotion.burst,
    shape: WinEffectShape.rect,
    colors: [
      Color(0xFFFF0000), Color(0xFFFF9800), Color(0xFFFFEB3B),
      Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFF9C27B0),
    ],
  ),
];

/// Live (bundled+remote merged) catalog — populated by CosmeticsCatalogService.
List<WinEffect>? liveWinEffects;

/// Full catalog incl. inactive; store screens filter on [WinEffect.active].
List<WinEffect> get allWinEffects => liveWinEffects ?? kWinEffects;

WinEffect winEffectFor(String? id) {
  if (id == null) return allWinEffects.first;
  for (final e in allWinEffects) {
    if (e.id == id) return e;
  }
  return allWinEffects.first;
}
