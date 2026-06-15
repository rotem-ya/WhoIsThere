/// Content categories for the game. Each category has its own bundled JSON
/// catalogue (assets/game_places/data/<id>.json) and can also receive new
/// places at runtime via the Firebase content manifest (matched by `category`).
///
/// Only [israelPlaces] is wired into the live UI today; the others are
/// infrastructure — their catalogues start empty and fill via content packs or
/// the admin manifest. The player-facing category picker is a later step.
class GameCategory {
  final String id;
  final String nameHe;
  final String emoji;
  final String assetPath;
  // When true, bundled entries are gated by RoomService's in-app id allowlist
  // (legacy behavior for the original Israel-places catalogue). Other categories
  // simply use every active entry in their JSON file.
  final bool useAllowlist;
  // When false, the in-game hint feature is suppressed for this category.
  final bool hasHints;

  const GameCategory({
    required this.id,
    required this.nameHe,
    required this.emoji,
    required this.assetPath,
    this.useAllowlist = false,
    this.hasHints = true,
  });
}

class GameCategories {
  GameCategories._();

  static const String israelPlaces = 'israel_places';
  static const String animals = 'animals';
  static const String plants = 'plants';
  static const String objects = 'objects';
  static const String worldSites = 'world_sites';
  static const String israelFigures = 'israel_figures';
  static const String worldFigures = 'world_figures';

  static const String _dataDir = 'assets/game_places/data';

  static const List<GameCategory> all = [
    GameCategory(
      id: israelPlaces,
      nameHe: 'מקומות בישראל',
      emoji: '🇮🇱',
      assetPath: '$_dataDir/israel_places.json',
      useAllowlist: true,
    ),
    GameCategory(
      id: animals,
      nameHe: 'חיות',
      emoji: '🐾',
      assetPath: '$_dataDir/animals.json',
      hasHints: false, // animals play without hints
    ),
    GameCategory(
      id: plants,
      nameHe: 'צומח',
      emoji: '🌿',
      assetPath: '$_dataDir/plants.json',
      hasHints: false,
    ),
    GameCategory(
      id: objects,
      nameHe: 'דומם',
      emoji: '🪑',
      assetPath: '$_dataDir/objects.json',
      hasHints: false,
    ),
    GameCategory(
      id: worldSites,
      nameHe: 'אתרים בעולם',
      emoji: '🌍',
      assetPath: '$_dataDir/world_sites.json',
    ),
    GameCategory(
      id: israelFigures,
      nameHe: 'דמויות מוכרות בישראל',
      emoji: '🧑',
      assetPath: '$_dataDir/israel_figures.json',
    ),
    GameCategory(
      id: worldFigures,
      nameHe: 'דמויות מוכרות בעולם',
      emoji: '🌐',
      assetPath: '$_dataDir/world_figures.json',
    ),
  ];

  /// Resolves a category id to its descriptor, defaulting to Israel places so a
  /// missing/unknown id never breaks the existing flow.
  static GameCategory byId(String? id) => all.firstWhere(
        (c) => c.id == id,
        orElse: () => all.first,
      );

  /// The fast game ("מקצה") plays one quick round per category, in this order:
  /// animal → plant → inanimate (חי / צומח / דומם). Categories without content
  /// are skipped, so the heat fills as content lands.
  static const List<String> fastHeat = [animals, plants, objects];
}
