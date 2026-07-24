import 'daily_quest.dart' show QuestKind;
import 'rewards_config.dart';

/// Per-user quest progress state, stored at `users/{uid}/economy/quests`.
/// Progress is measured as the delta of a lifetime counter (wins / plays /
/// discoveries) since each quest's baseline, so no per-event hooks are needed.
/// A period (daily = UTC day, weekly = ISO week) resets baselines + claims.

/// UTC day key, e.g. "2026-07-24".
String questDayKeyOf([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// ISO-8601 week key, e.g. "2026-W30" (week belongs to the year of its Thursday).
String questWeekKeyOf([DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  final date = DateTime.utc(n.year, n.month, n.day);
  final thursday = date.add(Duration(days: 4 - date.weekday)); // Mon=1..Sun=7
  final firstDay = DateTime.utc(thursday.year, 1, 1);
  final week = (thursday.difference(firstDay).inDays / 7).floor() + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

class QuestPeriod {
  final String periodKey;
  final Map<String, int> baselines; // questId -> counter at period start
  final Set<String> claimed; // questIds already claimed this period

  const QuestPeriod({
    required this.periodKey,
    required this.baselines,
    required this.claimed,
  });

  factory QuestPeriod.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      return const QuestPeriod(periodKey: '', baselines: {}, claimed: {});
    }
    final base = <String, int>{};
    (m['baselines'] as Map?)?.forEach((k, v) {
      base['$k'] = (v as num?)?.toInt() ?? 0;
    });
    final claimed = ((m['claimed'] as List?) ?? const [])
        .map((e) => '$e')
        .toSet();
    return QuestPeriod(
      periodKey: m['periodKey'] as String? ?? '',
      baselines: base,
      claimed: claimed,
    );
  }

  Map<String, dynamic> toMap() => {
        'periodKey': periodKey,
        'baselines': baselines,
        'claimed': claimed.toList(),
      };
}

class QuestsDoc {
  final QuestPeriod daily;
  final QuestPeriod weekly;
  const QuestsDoc({required this.daily, required this.weekly});

  factory QuestsDoc.fromMap(Map<String, dynamic> m) => QuestsDoc(
        daily: QuestPeriod.fromMap(m['daily'] as Map<String, dynamic>?),
        weekly: QuestPeriod.fromMap(m['weekly'] as Map<String, dynamic>?),
      );

  Map<String, dynamic> toMap() =>
      {'daily': daily.toMap(), 'weekly': weekly.toMap()};
}

/// Live view of a single quest: its definition + current progress + claimed.
class QuestView {
  final QuestDef def;
  final bool weekly;
  final int progress; // 0..target
  final bool claimed;
  const QuestView({
    required this.def,
    required this.weekly,
    required this.progress,
    required this.claimed,
  });

  bool get complete => progress >= def.target;
  bool get claimable => complete && !claimed;
  double get ratio => def.target <= 0 ? 1 : (progress / def.target).clamp(0, 1);
}

int counterForKind(QuestKind kind,
    {required int wins, required int plays, required int discoveries}) {
  switch (kind) {
    case QuestKind.win:
      return wins;
    case QuestKind.play:
      return plays;
    case QuestKind.discover:
      return discoveries;
  }
}
