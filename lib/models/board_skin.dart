import 'package:flutter/material.dart';

enum BoardSkinTier { free, basic, rare, premium }

/// A cosmetic background for the in-game board screen (the area behind the tile
/// grid). Each player sees their own equipped skin. Rendered in code from
/// [colors] as a vertical gradient; 'none' falls back to the app default.
class BoardSkin {
  final String id;
  final String name;
  final int price;
  final List<Color> colors;

  /// Admin-created skins may be a full background IMAGE (generated via Gemini
  /// and hosted in Storage) instead of a gradient. When set, the game renders
  /// the image; [colors] still provides the accent + store swatch.
  final String? imageUrl;

  /// Hidden from the store when false (still renders if already equipped).
  final bool active;

  const BoardSkin({
    required this.id,
    required this.name,
    required this.price,
    this.colors = const [],
    this.imageUrl,
    this.active = true,
  });

  bool get isNone => id == 'none' || (colors.isEmpty && imageUrl == null);
  bool get isFree => price == 0;

  BoardSkinTier get tier {
    if (price == 0) return BoardSkinTier.free;
    if (price <= 150) return BoardSkinTier.basic;
    if (price < 1000) return BoardSkinTier.rare;
    return BoardSkinTier.premium;
  }

  Color get accent => colors.isEmpty ? const Color(0xFF4472C8) : colors.first;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors.length == 1 ? [colors.first, colors.first] : colors,
      );
}

const kBoardSkins = <BoardSkin>[
  // ── חינמי (ברירת מחדל) ───────────────────────────────────────────────────────
  BoardSkin(id: 'none', name: 'ברירת מחדל', price: 0),

  // ── בסיסי (50–150) ───────────────────────────────────────────────────────────
  BoardSkin(id: 'midnight', name: 'חצות',     price: 50,  colors: [Color(0xFF13294B), Color(0xFF050A16)]),
  BoardSkin(id: 'deep_sea', name: 'מצולות',   price: 70,  colors: [Color(0xFF003B46), Color(0xFF001518)]),
  BoardSkin(id: 'plum',     name: 'שזיף',     price: 90,  colors: [Color(0xFF2E1A47), Color(0xFF0E0518)]),
  BoardSkin(id: 'forest',   name: 'יער עד',   price: 110, colors: [Color(0xFF14331F), Color(0xFF04120A)]),
  BoardSkin(id: 'ember',    name: 'גחלים',    price: 150, colors: [Color(0xFF3A1410), Color(0xFF120403)]),

  // ── נדיר (300–500) ───────────────────────────────────────────────────────────
  BoardSkin(id: 'aurora',   name: 'זוהר הקוטב', price: 300, colors: [Color(0xFF0B3D2E), Color(0xFF134E6F), Color(0xFF050A1A)]),
  BoardSkin(id: 'sunset',   name: 'שקיעה',      price: 380, colors: [Color(0xFF4A1942), Color(0xFF8A2D4B), Color(0xFF1A0512)]),
  BoardSkin(id: 'galaxy',   name: 'גלקסיה',     price: 500, colors: [Color(0xFF1A0B3D), Color(0xFF3D1A6E), Color(0xFF05030F)]),

  // ── פרימיום (1000) ───────────────────────────────────────────────────────────
  BoardSkin(id: 'royal_gold', name: 'זהב מלכותי', price: 1000, colors: [Color(0xFF4A3A0B), Color(0xFF8A6D1A), Color(0xFF120D02)]),
  BoardSkin(id: 'nebula',     name: 'ערפילית',    price: 1000, colors: [Color(0xFF2B0B3D), Color(0xFF0B2B6E), Color(0xFF6E0B4E), Color(0xFF05030F)]),
  BoardSkin(id: 'emerald_dream', name: 'חלום אמרלד', price: 1000, colors: [Color(0xFF043D2E), Color(0xFF0B6E4E), Color(0xFF02120C)]),
];

/// Live (bundled+remote merged) catalog — populated by CosmeticsCatalogService.
/// Null until a live catalog was applied; every reader falls back to bundled.
List<BoardSkin>? liveBoardSkins;

/// The full catalog (incl. inactive, so an equipped-but-hidden skin still
/// renders). Store screens should filter on [BoardSkin.active].
List<BoardSkin> get allBoardSkins => liveBoardSkins ?? kBoardSkins;

BoardSkin boardSkinFor(String? id) {
  if (id == null) return allBoardSkins.first;
  for (final s in allBoardSkins) {
    if (s.id == id) return s;
  }
  return allBoardSkins.first;
}
