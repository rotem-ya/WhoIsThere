import 'daily_quest.dart' show QuestKind;

/// Admin-controlled rewards configuration, read live from Firestore
/// `rewards_config/config_v1`. Every piece falls back to an embedded default so
/// the game behaves exactly as before until the admin publishes a config.
///
/// See docs/REWARDS_HUB_DESIGN.md for the schema and contract.

QuestKind _questKindFrom(String? s) {
  switch (s) {
    case 'play':
      return QuestKind.play;
    case 'discover':
      return QuestKind.discover;
    case 'win':
    default:
      return QuestKind.win;
  }
}

class SpinConfig {
  final bool enabled;
  final List<int> segments;
  final List<int> weights;
  const SpinConfig(
      {required this.enabled, required this.segments, required this.weights});

  static const fallback = SpinConfig(
    enabled: true,
    segments: [10, 25, 50, 15, 100, 30, 75, 20],
    weights: [26, 18, 8, 22, 2, 14, 4, 20],
  );

  factory SpinConfig.fromMap(Map<String, dynamic>? m) {
    if (m == null) return fallback;
    final segs = (m['segments'] as List?)?.map((e) => (e as num).toInt()).toList();
    final wts = (m['weights'] as List?)?.map((e) => (e as num).toInt()).toList();
    // Guard: both present, same non-trivial length, else fall back.
    if (segs == null ||
        wts == null ||
        segs.isEmpty ||
        segs.length != wts.length) {
      return fallback;
    }
    return SpinConfig(
      enabled: m['enabled'] as bool? ?? true,
      segments: segs,
      weights: wts,
    );
  }
}

class HappyHour {
  final bool enabled;
  final int multiplier;
  final String label;
  final DateTime? startUtc;
  final DateTime? endUtc;
  const HappyHour({
    required this.enabled,
    required this.multiplier,
    required this.label,
    this.startUtc,
    this.endUtc,
  });

  static const fallback =
      HappyHour(enabled: false, multiplier: 2, label: 'שעת המזל!');

  bool activeAt(DateTime nowUtc) =>
      enabled &&
      multiplier > 1 &&
      startUtc != null &&
      endUtc != null &&
      nowUtc.isAfter(startUtc!) &&
      nowUtc.isBefore(endUtc!);

  /// The coin multiplier right now (1 when inactive).
  int multiplierAt(DateTime nowUtc) => activeAt(nowUtc) ? multiplier : 1;

  factory HappyHour.fromMap(Map<String, dynamic>? m) {
    if (m == null) return fallback;
    DateTime? parse(String key) {
      final s = m[key] as String?;
      if (s == null || s.isEmpty) return null;
      return DateTime.tryParse(s)?.toUtc();
    }

    return HappyHour(
      enabled: m['enabled'] as bool? ?? false,
      multiplier: (m['multiplier'] as num? ?? 2).toInt().clamp(1, 10),
      label: (m['label'] as String?)?.trim().isNotEmpty == true
          ? m['label'] as String
          : 'שעת המזל!',
      startUtc: parse('startUtc'),
      endUtc: parse('endUtc'),
    );
  }
}

class QuestDef {
  final String id;
  final QuestKind kind;
  final String emoji;
  final String title;
  final int target;
  final int reward;
  final bool active;
  const QuestDef({
    required this.id,
    required this.kind,
    required this.emoji,
    required this.title,
    required this.target,
    required this.reward,
    this.active = true,
  });

  factory QuestDef.fromMap(Map<String, dynamic> m) => QuestDef(
        id: m['id'] as String? ?? '',
        kind: _questKindFrom(m['kind'] as String?),
        emoji: m['emoji'] as String? ?? '⭐',
        title: m['title'] as String? ?? 'מטלה',
        target: (m['target'] as num? ?? 1).toInt().clamp(1, 100000),
        reward: (m['reward'] as num? ?? 0).toInt().clamp(0, 100000),
        active: m['active'] as bool? ?? true,
      );
}

class RewardsConfig {
  final SpinConfig spin;
  final HappyHour happyHour;
  final List<QuestDef> dailyQuests;
  final List<QuestDef> weeklyQuests;
  const RewardsConfig({
    required this.spin,
    required this.happyHour,
    required this.dailyQuests,
    required this.weeklyQuests,
  });

  static const List<QuestDef> _fallbackDaily = [
    QuestDef(id: 'win2', kind: QuestKind.win, emoji: '🏆', title: 'נצחו 2 משחקים', target: 2, reward: 40),
    QuestDef(id: 'play3', kind: QuestKind.play, emoji: '🎮', title: 'שחקו 3 משחקים', target: 3, reward: 30),
    QuestDef(id: 'discover5', kind: QuestKind.discover, emoji: '🗺️', title: 'גלו 5 מקומות חדשים', target: 5, reward: 50),
  ];
  static const List<QuestDef> _fallbackWeekly = [
    QuestDef(id: 'win15', kind: QuestKind.win, emoji: '🏅', title: 'נצחו 15 משחקים השבוע', target: 15, reward: 150),
    QuestDef(id: 'discover20', kind: QuestKind.discover, emoji: '🌍', title: 'גלו 20 מקומות השבוע', target: 20, reward: 120),
  ];

  static const fallback = RewardsConfig(
    spin: SpinConfig.fallback,
    happyHour: HappyHour.fallback,
    dailyQuests: _fallbackDaily,
    weeklyQuests: _fallbackWeekly,
  );

  List<QuestDef> get activeDaily =>
      dailyQuests.where((q) => q.active && q.id.isNotEmpty).toList();
  List<QuestDef> get activeWeekly =>
      weeklyQuests.where((q) => q.active && q.id.isNotEmpty).toList();

  factory RewardsConfig.fromMap(Map<String, dynamic> m) {
    List<QuestDef> quests(String key, List<QuestDef> fb) {
      final raw = m[key] as List?;
      if (raw == null) return fb;
      final list = raw
          .whereType<Map>()
          .map((e) => QuestDef.fromMap(Map<String, dynamic>.from(e)))
          .where((q) => q.id.isNotEmpty)
          .toList();
      return list.isEmpty ? fb : list;
    }

    return RewardsConfig(
      spin: SpinConfig.fromMap(m['spin'] as Map<String, dynamic>?),
      happyHour: HappyHour.fromMap(m['happyHour'] as Map<String, dynamic>?),
      dailyQuests: quests('dailyQuests', _fallbackDaily),
      weeklyQuests: quests('weeklyQuests', _fallbackWeekly),
    );
  }
}
