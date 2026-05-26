import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  matchWin,
  matchParticipation,
  hintRevealTile,
  hintExtraGuess,
  dailyReward,
  adReward,
  coinPurchase,
  adminAdjustment,
  wrongGuessPenalty,
  guessTimeoutPenalty,
  stabilityCompensation,
  roomEntryFee,
  guessClaimFee,
  wrongGuessPotPenalty,
  potWin,
  potRefund,
  stunCardPurchase,
  guessBlock5Purchase,
  guessBlock10Purchase,
  blackoutCardPurchase,
}

class EconomyTransactionModel {
  final String id;
  final TransactionType type;
  final int delta;          // positive = earn, negative = spend
  final int balanceAfter;
  final String? roomId;     // set for match-related transactions
  final DateTime createdAt;
  final Map<String, dynamic> meta; // extra context (e.g. streak day)

  const EconomyTransactionModel({
    required this.id,
    required this.type,
    required this.delta,
    required this.balanceAfter,
    this.roomId,
    required this.createdAt,
    this.meta = const {},
  });

  factory EconomyTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EconomyTransactionModel(
      id: doc.id,
      type: TransactionType.values.firstWhere(
        (e) => e.name == (d['type'] as String),
        orElse: () => TransactionType.adminAdjustment,
      ),
      delta: (d['delta'] as num).toInt(),
      balanceAfter: (d['balanceAfter'] as num).toInt(),
      roomId: d['roomId'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate().toUtc(),
      meta: Map<String, dynamic>.from(d['meta'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'delta': delta,
        'balanceAfter': balanceAfter,
        if (roomId != null) 'roomId': roomId,
        'createdAt': Timestamp.fromDate(createdAt),
        'meta': meta,
      };
}
