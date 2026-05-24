class CardSkin {
  final String id;
  final String name;
  final int price;
  final String? assetPath;

  const CardSkin({
    required this.id,
    required this.name,
    required this.price,
    this.assetPath,
  });

  bool get isFree => price == 0;
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
