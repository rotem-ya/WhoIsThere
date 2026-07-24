import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_quest.dart' show QuestKind;
import '../models/economy/economy_transaction_model.dart';
import '../models/economy/user_economy_model.dart';
import '../models/quests_state.dart';
import '../models/rewards_config.dart';
import 'qa_logger_service.dart';
import 'rewards_config_service.dart';

/// Drives the daily + weekly quest lists (definitions come from the admin
/// rewards config). State lives at `users/{uid}/economy/quests` (covered by the
/// economy self-access rule — no new Firestore rule). Progress is a baseline
/// delta of lifetime counters, so no per-event wiring is needed.
class QuestsService {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();
  QuestsService(this._db);

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.doc('users/$uid/economy/quests');
  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _db.doc('users/$uid/economy/wallet');

  Stream<QuestsDoc?> stream(String uid) => _ref(uid).snapshots().map(
      (s) => s.exists ? QuestsDoc.fromMap(s.data()!) : null);

  int _counter(QuestKind kind, int wins, int plays, int discoveries) =>
      counterForKind(kind, wins: wins, plays: plays, discoveries: discoveries);

  /// Ensures both periods exist with fresh baselines for the current day/week,
  /// and seeds a baseline for any quest id added mid-period. Cheap and safe to
  /// call often (writes only when something actually changes). Fire-and-forget.
  Future<void> ensurePeriods(
    String uid, {
    required int wins,
    required int plays,
    required int discoveries,
    required List<QuestDef> dailyDefs,
    required List<QuestDef> weeklyDefs,
  }) async {
    try {
      final snap = await _ref(uid).get();
      final doc = snap.exists
          ? QuestsDoc.fromMap(snap.data()!)
          : const QuestsDoc(
              daily: QuestPeriod(periodKey: '', baselines: {}, claimed: {}),
              weekly: QuestPeriod(periodKey: '', baselines: {}, claimed: {}));

      final dayKey = questDayKeyOf();
      final weekKey = questWeekKeyOf();

      QuestPeriod refresh(QuestPeriod p, String key, List<QuestDef> defs) {
        if (p.periodKey != key) {
          // New period: reset baselines to current counters, clear claims.
          return QuestPeriod(
            periodKey: key,
            baselines: {
              for (final d in defs)
                d.id: _counter(d.kind, wins, plays, discoveries)
            },
            claimed: {},
          );
        }
        // Same period: seed baseline for any newly-added quest id.
        final base = Map<String, int>.from(p.baselines);
        var added = false;
        for (final d in defs) {
          if (!base.containsKey(d.id)) {
            base[d.id] = _counter(d.kind, wins, plays, discoveries);
            added = true;
          }
        }
        return added
            ? QuestPeriod(periodKey: key, baselines: base, claimed: p.claimed)
            : p;
      }

      final newDaily = refresh(doc.daily, dayKey, dailyDefs);
      final newWeekly = refresh(doc.weekly, weekKey, weeklyDefs);

      if (!snap.exists ||
          newDaily.periodKey != doc.daily.periodKey ||
          newWeekly.periodKey != doc.weekly.periodKey ||
          newDaily.baselines.length != doc.daily.baselines.length ||
          newWeekly.baselines.length != doc.weekly.baselines.length) {
        await _ref(uid)
            .set(QuestsDoc(daily: newDaily, weekly: newWeekly).toMap());
      }
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('ECONOMY',
          'QUESTS_ENSURE_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
    }
  }

  /// Build the live list of quest views (daily then weekly) from the stored
  /// doc + current counters + config defs.
  List<QuestView> viewsFrom(
    QuestsDoc? doc, {
    required int wins,
    required int plays,
    required int discoveries,
    required List<QuestDef> dailyDefs,
    required List<QuestDef> weeklyDefs,
  }) {
    List<QuestView> build(
        QuestPeriod? p, List<QuestDef> defs, bool weekly, String key) {
      if (p == null || p.periodKey != key) return const [];
      return defs.map((d) {
        final base = p.baselines[d.id];
        final counter = _counter(d.kind, wins, plays, discoveries);
        final progress =
            base == null ? 0 : (counter - base).clamp(0, d.target);
        return QuestView(
          def: d,
          weekly: weekly,
          progress: progress,
          claimed: p.claimed.contains(d.id),
        );
      }).toList();
    }

    return [
      ...build(doc?.daily, dailyDefs, false, questDayKeyOf()),
      ...build(doc?.weekly, weeklyDefs, true, questWeekKeyOf()),
    ];
  }

  /// Claim one completed quest. Idempotent per (period, questId). Returns the
  /// coins granted (after Happy Hour), or null if not claimable.
  Future<int?> claim(
    String uid, {
    required QuestDef def,
    required bool weekly,
    required int wins,
    required int plays,
    required int discoveries,
  }) async {
    final key = weekly ? questWeekKeyOf() : questDayKeyOf();
    int? granted;
    try {
      await _db.runTransaction((tx) async {
        final qSnap = await tx.get(_ref(uid));
        if (!qSnap.exists) return;
        final doc = QuestsDoc.fromMap(qSnap.data()!);
        final period = weekly ? doc.weekly : doc.daily;
        if (period.periodKey != key) return; // rolled over
        if (period.claimed.contains(def.id)) return; // already claimed
        final base = period.baselines[def.id];
        if (base == null) return;
        final counter = _counter(def.kind, wins, plays, discoveries);
        if (counter - base < def.target) return; // not complete

        final reward =
            def.reward * RewardsConfigService.instance.happyHourMultiplier;

        final wSnap = await tx.get(_walletRef(uid));
        final wallet = wSnap.exists
            ? UserEconomyModel.fromFirestore(uid, wSnap.data()!)
            : UserEconomyModel.empty(uid);
        final updated = wallet.copyWith(
          coins: wallet.coins + reward,
          totalEarned: wallet.totalEarned + reward,
        );
        tx.set(_walletRef(uid), updated.toFirestore());

        final txId = _uuid.v4();
        tx.set(
            _db.collection('users/$uid/economy_transactions').doc(txId),
            EconomyTransactionModel(
              id: txId,
              type: TransactionType.dailyQuest,
              delta: reward,
              balanceAfter: updated.coins,
              createdAt: DateTime.now().toUtc(),
              meta: {'questId': def.id, 'weekly': weekly},
            ).toFirestore());

        tx.update(_ref(uid), {
          '${weekly ? 'weekly' : 'daily'}.claimed':
              FieldValue.arrayUnion([def.id]),
        });
        granted = reward;
      });
    } catch (e) {
      final msg = e.toString();
      QaLoggerService.instance.log('ECONOMY',
          'QUEST_CLAIM_ERROR ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      rethrow;
    }
    return granted;
  }
}
