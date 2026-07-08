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

const kAvailableCardSkins = <CardSkin>[
  // ── חינמי (ברירת מחדל) ───────────────────────────────────────────────────────
  // Default card back is the Israeli flag (shares the classic_zionist artwork).
  // No assetPath → rendered by the painter, not a PNG.
  CardSkin(id: 'default', name: 'דגל ישראל', price: 0),

  // ── בסיסי (50–150 מטבעות) ───────────────────────────────────────────────────
  CardSkin(id: 'mediterranean_blue', name: 'כחול ים תיכון',  price: 50, assetPath: 'assets/skins/card_mediterranean_blue.jpg'),
  CardSkin(id: 'valley_green',       name: 'ירוק העמק',       price: 60, assetPath: 'assets/skins/card_valley_green.jpg'),
  CardSkin(id: 'negev_sands',        name: 'חולות הנגב',      price: 70, assetPath: 'assets/skins/card_negev_sands.jpg'),
  CardSkin(id: 'quiet_night',        name: 'לילה שקט',        price: 80, assetPath: 'assets/skins/card_quiet_night.jpg'),
  CardSkin(id: 'dawn_light',         name: 'אור שחר',         price: 90, assetPath: 'assets/skins/card_dawn_light.jpg'),
  CardSkin(id: 'urban_concrete',     name: 'בטון אורבני',     price: 100, assetPath: 'assets/skins/card_urban_concrete.jpg'),
  CardSkin(id: 'classic_zionist',    name: 'ציוני קלאסי',     price: 110, assetPath: 'assets/skins/card_classic_zionist.jpg'),
  CardSkin(id: 'summer_pastel',      name: 'גלידת קיץ',       price: 120, assetPath: 'assets/skins/card_summer_pastel.jpg'),
  CardSkin(id: 'simple_gold_basic',  name: 'זהב עדין',        price: 130, assetPath: 'assets/skins/card_simple_gold_basic.jpg'),
  CardSkin(id: 'terracotta_earth',   name: 'אדמת טרקוטה',     price: 150, assetPath: 'assets/skins/card_terracotta_earth.jpg'),

  // ── נדיר (300–500 מטבעות) ───────────────────────────────────────────────────
  CardSkin(id: 'jerusalem_neon',     name: 'נאון ירושלמי',    price: 300, assetPath: 'assets/skins/card_jerusalem_neon.jpg'),
  CardSkin(id: 'steel_armor',        name: 'שריון פלדה',      price: 320, assetPath: 'assets/skins/card_steel_armor.jpg'),
  CardSkin(id: 'space_cluster',      name: 'צביר החלל',       price: 340, assetPath: 'assets/skins/card_space_cluster.jpg'),
  CardSkin(id: 'blue_fire',          name: 'אש כחולה',        price: 360, assetPath: 'assets/skins/card_blue_fire.jpg'),
  CardSkin(id: 'hermon_glacier',     name: 'קרחון חרמון',     price: 380, assetPath: 'assets/skins/card_hermon_glacier.jpg'),
  CardSkin(id: 'oriental_arabesque', name: 'ערבסק מזרחי',     price: 400, assetPath: 'assets/skins/card_oriental_arabesque.jpg'),
  CardSkin(id: 'ancient_gold_rare',  name: 'זהב עתיק',        price: 420, assetPath: 'assets/skins/card_ancient_gold_rare.jpg'),
  CardSkin(id: 'brushed_titanium',   name: 'טיטניום מוברש',   price: 440, assetPath: 'assets/skins/card_brushed_titanium.jpg'),
  CardSkin(id: 'eilat_coral',        name: 'אלמוג אילת',      price: 460, assetPath: 'assets/skins/card_eilat_coral.jpg'),
  CardSkin(id: 'meteor_shower',      name: 'מטר מטאורים',     price: 500, assetPath: 'assets/skins/card_meteor_shower.jpg'),

  // ── פרימיום (1000 מטבעות) ───────────────────────────────────────────────────
  CardSkin(id: 'royal_throne',          name: 'כס המלכות',     price: 1000, assetPath: 'assets/skins/card_royal_throne.jpg'),
  CardSkin(id: 'ancient_scroll',        name: 'מגילה עתיקה',   price: 1000, assetPath: 'assets/skins/card_ancient_scroll.jpg'),
  CardSkin(id: 'jerusalem_of_gold',     name: 'ירושלים של זהב', price: 1000, assetPath: 'assets/skins/card_jerusalem_of_gold.jpg'),
  CardSkin(id: 'kotel_stones',          name: 'אבני הכותל',    price: 1000, assetPath: 'assets/skins/card_kotel_stones.jpg'),
  CardSkin(id: 'anemone_red',           name: 'אודם הכלניות',  price: 1000, assetPath: 'assets/skins/card_anemone_red.jpg'),
  CardSkin(id: 'salt_sunset',           name: 'שקיעת מלח',     price: 1000, assetPath: 'assets/skins/card_salt_sunset.jpg'),
  CardSkin(id: 'royal_sapphire',        name: 'ספיר מלכותי',   price: 1000, assetPath: 'assets/skins/card_royal_sapphire.jpg'),
  CardSkin(id: 'lava_core',             name: 'ליבת הלבה',     price: 1000, assetPath: 'assets/skins/card_lava_core.jpg'),
  CardSkin(id: 'diamond_shield',        name: 'מגן יהלום',     price: 1000, assetPath: 'assets/skins/card_diamond_shield.jpg'),
  CardSkin(id: 'cyber_future_israel',   name: 'ישראל 2077',    price: 1000, assetPath: 'assets/skins/card_cyber_future_israel.jpg'),
];
