enum SkinTier { free, basic, rare, premium }

class CardSkin {
  final String id;
  final String name;
  final int price;
  final String? assetPath;
  final String? coverImageUrl;
  final String? previewImageUrl;

  const CardSkin({
    required this.id,
    required this.name,
    required this.price,
    this.assetPath,
    this.coverImageUrl,
    this.previewImageUrl,
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
  CardSkin(id: 'default', name: 'מנדלה', price: 0, assetPath: 'assets/skins/default.png'),

  // ── בסיסי (50–150 מטבעות) ───────────────────────────────────────────────────
  CardSkin(id: 'mediterranean_blue', name: 'כחול ים תיכון',  price: 50),
  CardSkin(id: 'valley_green',       name: 'ירוק העמק',       price: 60),
  CardSkin(id: 'negev_sands',        name: 'חולות הנגב',      price: 70),
  CardSkin(id: 'quiet_night',        name: 'לילה שקט',        price: 80),
  CardSkin(id: 'dawn_light',         name: 'אור שחר',         price: 90),
  CardSkin(id: 'urban_concrete',     name: 'בטון אורבני',     price: 100),
  CardSkin(id: 'classic_zionist',    name: 'ציוני קלאסי',     price: 110),
  CardSkin(id: 'summer_pastel',      name: 'גלידת קיץ',       price: 120),
  CardSkin(id: 'simple_gold_basic',  name: 'זהב עדין',        price: 130),
  CardSkin(id: 'terracotta_earth',   name: 'אדמת טרקוטה',     price: 150),

  // ── נדיר (300–500 מטבעות) ───────────────────────────────────────────────────
  CardSkin(id: 'jerusalem_neon',     name: 'נאון ירושלמי',    price: 300),
  CardSkin(id: 'steel_armor',        name: 'שריון פלדה',      price: 320),
  CardSkin(id: 'space_cluster',      name: 'צביר החלל',       price: 340),
  CardSkin(id: 'blue_fire',          name: 'אש כחולה',        price: 360),
  CardSkin(id: 'hermon_glacier',     name: 'קרחון חרמון',     price: 380),
  CardSkin(id: 'oriental_arabesque', name: 'ערבסק מזרחי',     price: 400),
  CardSkin(id: 'ancient_gold_rare',  name: 'זהב עתיק',        price: 420),
  CardSkin(id: 'brushed_titanium',   name: 'טיטניום מוברש',   price: 440),
  CardSkin(id: 'eilat_coral',        name: 'אלמוג אילת',      price: 460),
  CardSkin(id: 'meteor_shower',      name: 'מטר מטאורים',     price: 500),

  // ── פרימיום (1000 מטבעות) ───────────────────────────────────────────────────
  CardSkin(id: 'royal_throne',          name: 'כס המלכות',     price: 1000),
  CardSkin(id: 'ancient_scroll',        name: 'מגילה עתיקה',   price: 1000),
  CardSkin(id: 'jerusalem_of_gold',     name: 'ירושלים של זהב', price: 1000),
  CardSkin(id: 'kotel_stones',          name: 'אבני הכותל',    price: 1000),
  CardSkin(id: 'anemone_red',           name: 'אודם הכלניות',  price: 1000),
  CardSkin(id: 'salt_sunset',           name: 'שקיעת מלח',     price: 1000),
  CardSkin(id: 'royal_sapphire',        name: 'ספיר מלכותי',   price: 1000),
  CardSkin(id: 'lava_core',             name: 'ליבת הלבה',     price: 1000),
  CardSkin(id: 'diamond_shield',        name: 'מגן יהלום',     price: 1000),
  CardSkin(id: 'cyber_future_israel',   name: 'ישראל 2077',    price: 1000),
];
