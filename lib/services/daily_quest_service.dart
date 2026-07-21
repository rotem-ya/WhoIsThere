import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_quest.dart';
import '../models/economy/economy_transaction_model.dart';
import '../models/economy/user_economy_model.dart';
import 'qa_logger_service.dart';

/// Drives the rotating daily quest. State lives in
/// `users/{uid}/economy/daily_quest` (covered by the economy self-access rule);
/// progress is the delta of a lifetime counter since the quest's baseline, so
/// no per-event wiring is needed. Reward is credited with a wallet transaction,
/// idempotent per UTC day via the `claimed` flag.
class DailyQuestService {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  DailyQuestService(this._db);

  DocumentReference<Map<String, dynamic>> _questRef(String uid) =>
      _db.doc('users/$uid/economy/daily_quest');

  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _db.doc('users/$uid/economy/wallet');

  Stream<DailyQuestModel?> questStream(String uid) =>
      _questRef(uid).snapshots().map(
          (s) => s.exists ? DailyQuestModel.fromMap(s.data()!) : null);

  int _counterFor(QuestKind kind,
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

  /// Ensures today's quest exists with a fresh baseline. Safe to call often:
  /// it only writes when the stored day differs from today.
  Future<void> ensureToday(
    String uid, {
    required int wins,
    required int plays,
    required int discoveries,
  }) async {
    final today = questDayKey();
    final snap = await _questRef(uid).get();
    if (snap.exists && (snap.data()?['dayKey'] as String?) == today) return;

    final index = questIndexForDay();
    final baseline = _counterFor(kDailyQuests[index].kind,
        wins: wins, plays: plays, discoveries: discoveries);
    await _questRef(uid).set(DailyQuestModel(
      dayKey: today,
      index: index,
      baseline: baseline,
      claimed: false,
    ).toMap());
  }

  /// Compute the live state from a stored record + current counters.
  DailyQuestState? stateFrom(
    DailyQuestModel? model, {
    required int wins,
    required int plays,
    required int discoveries,
  }) {
    if (model == null || model.dayKey != questDayKey()) return null;
    final template = kDailyQuests[model.index.clamp(0, kDailyQuests.length - 1)];
    final counter = _counterFor(template.kind,
        wins: wins, plays: plays, discoveries: discoveries);
    final progress = (counter - model.baseline).clamp(0, template.target);
    return DailyQuestState(
        template: template, progress: progress, claimed: model.claimed);
  }

  /// Claim today's reward once the target is met. Returns the coins granted, or
  /// null if not claimable (not complete / already claimed / day rolled over).
  Future<int?> claim(
    String uid, {
    required int wins,
    required int plays,
    required int discoveries,
  }) async {
    final today = questDayKey();
    int? granted;
    try {
      await _db.runTransaction((tx) async {
        final qSnap = await tx.get(_questRef(uid));
        if (!qSnap.exists) return;
        final model = DailyQuestModel.fromMap(qSnap.data()!);
        if (model.dayKey != today || model.claimed) return;

        final template =
            kDailyQuests[model.index.clamp(0, kDailyQuests.length - 1)];
        final counter = _counterFor(template.kind,
            wins: wins, plays: plays, discoveries: discoveries);
        if (counter - model.baseline < template.target) return;

        final wSnap = await tx.get(_walletRef(uid));
        final wallet = wSnap.exists
            ? UserEconomyModel.fromFirestore(uid, wSnap.data()!)
            : UserEconomyModel.empty(uid);
        final updated = wallet.copyWith(
          coins: wallet.coins + template.reward,
          totalEarned: wallet.totalEarned + template.reward,
        );
        tx.set(_walletRef(uid), updated.toFirestore());

        final txId = _uuid.v4();
        tx.set(
            _db.collection('users/$uid/economy_transactions').doc(txId),
            EconomyTransactionModel(
              id: txId,
              type: TransactionType.dailyQuest,
              delta: template.reward,
              balanceAfter: updated.coins,
              createdAt: DateTime.now().toUtc(),
              meta: {'dailyQuest': template.kind.name},
            ).toFirestore());

        tx.set(_questRef(uid), {'claimed': true},
            SetOptions(merge: true));
        granted = template.reward;
      });
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('ECONOMY',
          'DAILY_QUEST_CLAIM_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      rethrow;
    }
    return granted;
  }
}
