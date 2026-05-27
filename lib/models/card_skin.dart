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
  // ── חינמי ─────────────────────────────────────────────────────────────────
  CardSkin(id: 'default',   name: 'מנדלה',     price: 0,  assetPath: 'assets/skins/default.png'),
  CardSkin(id: 'classic',   name: 'קלאסי',      price: 0),
  CardSkin(id: 'ocean',     name: 'אוקיינוס',   price: 0),
  CardSkin(id: 'forest',    name: 'יער',         price: 0),
  CardSkin(id: 'sand',      name: 'חול',         price: 0),
  // ── פרימיום ───────────────────────────────────────────────────────────────
  CardSkin(id: 'blue',      name: 'כחול',        price: 20),
  CardSkin(id: 'red',       name: 'אדום',         price: 20),
  CardSkin(id: 'copper',    name: 'נחושת',        price: 25),
  CardSkin(id: 'dark',      name: 'לילה',         price: 30),
  CardSkin(id: 'emerald',   name: 'אמרלד',       price: 30),
  CardSkin(id: 'ruby',      name: 'רובי',         price: 35),
  CardSkin(id: 'rose_gold', name: 'זהב ורד',     price: 45),
  CardSkin(id: 'galaxy',    name: 'גלקסיה',      price: 50),
  CardSkin(id: 'obsidian',  name: 'אובסידיאן',   price: 60),
];
