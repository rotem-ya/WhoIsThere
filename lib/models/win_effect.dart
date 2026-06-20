import 'package:flutter/material.dart';

enum WinEffectTier { free, basic, rare, premium }

/// A celebratory particle effect shown on the win screen for the winner's
/// equipped effect. Rendered in code (no assets) by [WinEffectOverlay] from
/// [colors] + optional [emoji].
class WinEffect {
  final String id;
  final String name;
  final int price;

  /// Particle palette (used for shape particles, or as a glow tint for emoji).
  final List<Color> colors;

  /// When set, particles are this emoji instead of coloured shapes.
  final String? emoji;

  /// true = particles rise from the bottom; false = fall from the top.
  final bool rises;

  const WinEffect({
    required this.id,
    required this.name,
    required this.price,
    this.colors = const [],
    this.emoji,
    this.rises = false,
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
    colors: [
      Color(0xFFFF4081), Color(0xFF40C4FF), Color(0xFFFFD740),
      Color(0xFF69F0AE), Color(0xFFFF6E40),
    ],
  ),
  WinEffect(
    id: 'gold_shower',
    name: 'גשם זהב',
    price: 100,
    colors: [Color(0xFFFFE082), Color(0xFFFFD700), Color(0xFFC9A227)],
  ),
  WinEffect(
    id: 'bubbles',
    name: 'בועות',
    price: 150,
    colors: [Color(0xFF81D4FA), Color(0xFFE1F5FE), Color(0xFF4FC3F7)],
    rises: true,
  ),

  // ── נדיר (300–500) — אימוג'י ─────────────────────────────────────────────────
  WinEffect(
    id: 'stars',
    name: 'כוכבים',
    price: 300,
    colors: [Color(0xFFFFD740)],
    emoji: '⭐',
  ),
  WinEffect(
    id: 'hearts',
    name: 'לבבות',
    price: 400,
    colors: [Color(0xFFFF5A8A)],
    emoji: '❤️',
    rises: true,
  ),
  WinEffect(
    id: 'party',
    name: 'מסיבה',
    price: 500,
    colors: [Color(0xFFFFD740)],
    emoji: '🎉',
  ),

  // ── פרימיום (1000) ───────────────────────────────────────────────────────────
  WinEffect(
    id: 'fireworks',
    name: 'זיקוקים',
    price: 1000,
    colors: [Color(0xFFFFD740)],
    emoji: '🎆',
    rises: true,
  ),
  WinEffect(
    id: 'crown',
    name: 'כתר מלכים',
    price: 1000,
    colors: [Color(0xFFFFD700)],
    emoji: '👑',
  ),
  WinEffect(
    id: 'rainbow_confetti',
    name: 'קונפטי קשת',
    price: 1000,
    colors: [
      Color(0xFFFF0000), Color(0xFFFF9800), Color(0xFFFFEB3B),
      Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFF9C27B0),
    ],
  ),
];

WinEffect winEffectFor(String? id) {
  if (id == null) return kWinEffects.first;
  for (final e in kWinEffects) {
    if (e.id == id) return e;
  }
  return kWinEffects.first;
}
