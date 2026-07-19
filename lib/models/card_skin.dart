enum SkinTier { free, basic, rare, premium }

class CardSkin {
  final String id;
  final String name;
  final int price;
  final String? assetPath;
  final String? coverImageUrl;
  final String? previewImageUrl;

  /// Hidden from the store when false, but still rendered for players who
  /// already own it (removing a skin from sale must not break their board).
  final bool active;

  const CardSkin({
    required this.id,
    required this.name,
    required this.price,
    this.assetPath,
    this.coverImageUrl,
    this.previewImageUrl,
    this.active = true,
  });

  bool get isFree => price == 0;

  SkinTier get tier {
    if (price == 0) return SkinTier.free;
    if (price <= 150) return SkinTier.basic;
    if (price < 1000) return SkinTier.rare;
    return SkinTier.premium;
  }

  /// Whether this skin has a custom background image (asset or network).
  bool get hasImage => assetPath != null || coverImageUrl != null;

  factory CardSkin.fromFirestore(String id, Map<String, dynamic> data) {
    return CardSkin(
      id: id,
      name: (data['nameHe'] as String?) ?? id,
      price: (data['price'] as num?)?.toInt() ?? 0,
      coverImageUrl: data['coverImageUrl'] as String?,
      previewImageUrl: data['previewImageUrl'] as String?,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'nameHe': name,
        'price': price,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (previewImageUrl != null) 'previewImageUrl': previewImageUrl,
        'active': true,
      };
}

// Store catalog by price tier — 3 skins per tier (0/50/100/200/500) + 1 at 1000.
// Each tier is a distinct art style (see the admin's tierStyle):
//   0 minimalist · 50 Israeli nature · 100 oriental mosaic · 200 neon ·
//   500 cosmic · 1000 royal gold + diamonds + Magen David.
// Images are generated in the admin per tier and BAKED here (assetPath) each
// release; until baked they render procedurally / from a live cloud image.
// Covers render from the rich procedural styles in VaultCover (mapped via
// _kSkinStyleAlias) instead of baked photos — clean, designed, consistent with
// the Candy line. The free default reads as a royal Candy purple.
const kAvailableCardSkins = <CardSkin>[
  // Names describe the COLOR (the covers are solid Candy jelly, not patterns),
  // so what the store shows matches the name.
  // ── חינמי (0) ────────────────────────────────────────────────────────────────
  CardSkin(id: 'default',        name: 'סגול ענבים', price: 0),
  CardSkin(id: 'minimal_lines',  name: 'כחול שמיים', price: 0),
  CardSkin(id: 'minimal_calm',   name: 'טורקיז',     price: 0),

  // ── בסיסי · 50 ───────────────────────────────────────────────────────────────
  CardSkin(id: 'nature_leaves',  name: 'ליים',        price: 50),
  CardSkin(id: 'nature_waves',   name: 'כחול ים',     price: 50),
  CardSkin(id: 'nature_anemone', name: 'אדום כלנית',  price: 50),

  // ── בסיסי · 100 ──────────────────────────────────────────────────────────────
  CardSkin(id: 'mosaic_arabesque', name: 'אמטיסט', price: 100),
  CardSkin(id: 'mosaic_tiles',     name: 'אקווה',  price: 100),
  CardSkin(id: 'mosaic_star',      name: 'ענבר',   price: 100),

  // ── נדיר · 200 (נצנוץ עדין) ───────────────────────────────────────────────────
  CardSkin(id: 'neon_grid',  name: 'ורוד ניאון',  price: 200),
  CardSkin(id: 'neon_wave',  name: 'תכלת ניאון',  price: 200),
  CardSkin(id: 'neon_cyber', name: 'אינדיגו',      price: 200),

  // ── נדיר · 500 (נצנוץ עדין) ───────────────────────────────────────────────────
  CardSkin(id: 'cosmic_galaxy',  name: 'חלל עמוק',    price: 500),
  CardSkin(id: 'cosmic_aurora',  name: 'זוהר צפוני',  price: 500),
  CardSkin(id: 'cosmic_fireice', name: 'כתום להבה',   price: 500),

  // ── פרימיום · 1000 (זהב + מגן דוד + ברק מונפש) ───────────────────────────────
  CardSkin(id: 'royal_magen', name: 'מגן דוד מלכותי', price: 1000),
];
