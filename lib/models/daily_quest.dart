import 'package:cloud_firestore/cloud_firestore.dart';

/// What lifetime counter a quest measures progress against.
enum QuestKind { win, play, discover }

/// A daily quest template. The active quest rotates by UTC day so everyone sees
/// the same one, and progress is measured as the delta of a lifetime counter
/// since the quest started (baseline snapshot), which needs no per-event hooks.
class QuestTemplate {
  final QuestKind kind;
  final String emoji;
  final String label;
  final int target;
  final int reward;

  const QuestTemplate({
    required this.kind,
    required this.emoji,
    required this.label,
    required this.target,
    required this.reward,
  });
}

const List<QuestTemplate> kDailyQuests = [
  QuestTemplate(
      kind: QuestKind.win,
      emoji: '🏆',
      label: 'נצחו שני משחקים',
      target: 2,
      reward: 40),
  QuestTemplate(
      kind: QuestKind.play,
      emoji: '🎮',
      label: 'שחקו שלושה משחקים',
      target: 3,
      reward: 30),
  QuestTemplate(
      kind: QuestKind.discover,
      emoji: '🗺️',
      label: 'גלו חמישה מקומות חדשים',
      target: 5,
      reward: 50),
];

/// UTC day key, e.g. "2026-07-21".
String questDayKey([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

/// Which quest is active today (rotates through [kDailyQuests] by day).
int questIndexForDay([DateTime? now]) {
  final d = (now ?? DateTime.now()).toUtc();
  final days = DateTime.utc(d.year, d.month, d.day)
      .difference(DateTime.utc(2020, 1, 1))
      .inDays;
  return days % kDailyQuests.length;
}

/// The persisted per-user quest record (in users/{uid}/economy/daily_quest).
class DailyQuestModel {
  final String dayKey;
  final int index;
  final int baseline; // counter value when the quest started
  final bool claimed;

  const DailyQuestModel({
    required this.dayKey,
    required this.index,
    required this.baseline,
    required this.claimed,
  });

  factory DailyQuestModel.fromMap(Map<String, dynamic> d) => DailyQuestModel(
        dayKey: d['dayKey'] as String? ?? '',
        index: (d['index'] as num? ?? 0).toInt(),
        baseline: (d['baseline'] as num? ?? 0).toInt(),
        claimed: d['claimed'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'dayKey': dayKey,
        'index': index,
        'baseline': baseline,
        'claimed': claimed,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// The live, display-ready quest state: template + current progress.
class DailyQuestState {
  final QuestTemplate template;
  final int progress; // clamped 0..target
  final bool claimed;

  const DailyQuestState({
    required this.template,
    required this.progress,
    required this.claimed,
  });

  bool get isComplete => progress >= template.target;
  bool get canClaim => isComplete && !claimed;
  double get ratio =>
      template.target == 0 ? 1 : (progress / template.target).clamp(0.0, 1.0);
}
