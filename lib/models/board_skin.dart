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

  /// A BAKED local background image (bundled asset). When set it ALWAYS wins
  /// over [imageUrl] — renders instantly with no cloud read (release bake).
  final String? assetPath;

  /// Hidden from the store when false (still renders if already equipped).
  final bool active;

  const BoardSkin({
    required this.id,
    required this.name,
    required this.price,
    this.colors = const [],
    this.imageUrl,
    this.assetPath,
    this.active = true,
  });

  /// Whether this skin has a baked local background asset.
  bool get hasAsset => assetPath != null;

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

// Every skin renders from the layered code composition in BoardSkinBackground
// (base gradient + glows + starfields + vignette) — clean, designed, and
// consistent with the Candy line. No baked photos (they read as low-quality);
// [colors] still drives the store swatch + accent.
const kBoardSkins = <BoardSkin>[
  // ── חינמי (ברירת מחדל) — סגול Candy ─────────────────────────────────────────
  BoardSkin(id: 'none', name: 'ברירת מחדל', price: 0, colors: [Color(0xFF5B2AA6), Color(0xFF22103F)]),

  // ── בסיסי (50–150) ────────────────────────────────────────────────────────
  BoardSkin(id: 'midnight', name: 'חצות',     price: 50,  colors: [Color(0xFF18335A), Color(0xFF050A16)]),
  BoardSkin(id: 'deep_sea', name: 'מצולות',   price: 70,  colors: [Color(0xFF06343E), Color(0xFF00161C)]),
  BoardSkin(id: 'plum',     name: 'שזיף',     price: 90,  colors: [Color(0xFF351C53), Color(0xFF0E0518)]),
  BoardSkin(id: 'forest',   name: 'יער עד',   price: 110, colors: [Color(0xFF173B22), Color(0xFF04120A)]),
  BoardSkin(id: 'ember',    name: 'גחלים',    price: 150, colors: [Color(0xFF2A0D08), Color(0xFF120403)]),

  // ── נדיר (300–500) ───────────────────────────────────────────────────────────
  BoardSkin(id: 'aurora',   name: 'זוהר הקוטב', price: 300, colors: [Color(0xFF071326), Color(0xFF02060F)]),
  BoardSkin(id: 'sunset',   name: 'שקיעה',      price: 380, colors: [Color(0xFF2A1040), Color(0xFF8A2D4B), Color(0xFF1A0512)]),
  BoardSkin(id: 'galaxy',   name: 'גלקסיה',     price: 500, colors: [Color(0xFF160A33), Color(0xFF05030F)]),

  // ── פרימיום (1000) ───────────────────────────────────────────────────────────
  BoardSkin(id: 'royal_gold', name: 'זהב מלכותי', price: 1000, colors: [Color(0xFF221802), Color(0xFF0A0700)]),
  BoardSkin(id: 'nebula',     name: 'ערפילית',    price: 1000, colors: [Color(0xFF120633), Color(0xFF04020D)]),
  BoardSkin(id: 'emerald_dream', name: 'חלום אמרלד', price: 1000, colors: [Color(0xFF06392C), Color(0xFF02120C)]),
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
