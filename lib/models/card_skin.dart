class CardSkin {
  final String id;
  final String name;      // Hebrew name
  final int price;        // 0 = free/default
  final String? assetPath; // null = default programmatic iris

  const CardSkin({
    required this.id,
    required this.name,
    required this.price,
    this.assetPath,
  });
}

/// All available card skins. Add new entries here when new skins are added.
const kAvailableCardSkins = <CardSkin>[
  CardSkin(id: 'default', name: 'ברירת מחדל', price: 0),
  CardSkin(id: 'blue',    name: 'כחול',       price: 30,  assetPath: 'assets/skins/blue.png'),
  CardSkin(id: 'red',     name: 'אדום',        price: 30,  assetPath: 'assets/skins/red.png'),
  CardSkin(id: 'dark',    name: 'שחור',        price: 50,  assetPath: 'assets/skins/dark.png'),
];
