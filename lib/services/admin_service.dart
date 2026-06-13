import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/economy/economy_transaction_model.dart';
import '../models/economy/user_economy_model.dart';
import '../models/user_model.dart';
import 'qa_logger_service.dart';

/// Admin-only operations performed ON another user, looked up by login email.
///
/// All writes target other users' docs, so they only succeed for an account the
/// Firestore rules recognise as admin (custom claim `admin == true` OR an email
/// in AdminConfig.adminEmails — the rules mirror both). The acting admin's local
/// economy cache is never touched here (it belongs to the admin, not the target).
class AdminService {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  AdminService(this._db);

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.doc('users/$uid');
  DocumentReference<Map<String, dynamic>> _walletRef(String uid) =>
      _db.doc('users/$uid/economy/wallet');
  CollectionReference<Map<String, dynamic>> _txCol(String uid) =>
      _db.collection('users/$uid/economy_transactions');

  /// Finds a user by their (login) email. Email is stored lower-cased on the
  /// user doc at sign-in. Returns null if no user carries that email yet (e.g.
  /// they signed in before the email-persistence build, or are a guest).
  Future<UserModel?> findUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromFirestore(snap.docs.first);
  }

  /// Current wallet for a target user (coins etc.).
  Future<UserEconomyModel> getWallet(String uid) async {
    final snap = await _walletRef(uid).get();
    if (!snap.exists) return UserEconomyModel.empty(uid);
    return UserEconomyModel.fromFirestore(uid, snap.data()!);
  }

  /// Grants (or removes, if negative) coins to a target user and logs an
  /// adminAdjustment transaction. Returns the new balance.
  Future<int> grantCoins({
    required String uid,
    required int amount,
    String? adminEmail,
  }) async {
    int newBalance = 0;
    await _db.runTransaction((tx) async {
      final ref = _walletRef(uid);
      final snap = await tx.get(ref);
      final wallet = snap.exists
          ? UserEconomyModel.fromFirestore(uid, snap.data()!)
          : UserEconomyModel.empty(uid);

      final updatedCoins = (wallet.coins + amount).clamp(0, 1 << 31);
      final updated = wallet.copyWith(
        coins: updatedCoins,
        // Count positive admin grants toward lifetime earnings so the first-
        // install bonus guard (totalEarned > 0) stays correct.
        totalEarned:
            amount > 0 ? wallet.totalEarned + amount : wallet.totalEarned,
      );
      tx.set(ref, updated.toFirestore());

      final txId = _uuid.v4();
      tx.set(_txCol(uid).doc(txId), EconomyTransactionModel(
        id: txId,
        type: TransactionType.adminAdjustment,
        delta: amount,
        balanceAfter: updatedCoins,
        createdAt: DateTime.now().toUtc(),
        meta: {'admin': adminEmail ?? 'admin'},
      ).toFirestore());

      newBalance = updatedCoins;
    });
    QaLoggerService.instance.log('ADMIN',
        'GRANT_COINS uid=${uid.substring(0, uid.length.clamp(0, 6))} amount=$amount newBalance=$newBalance');
    return newBalance;
  }

  /// Adds a card-back skin to the target user's owned list.
  Future<void> grantSkin({required String uid, required String skinId}) async {
    await _userRef(uid).set({
      'ownedSkins': FieldValue.arrayUnion([skinId]),
    }, SetOptions(merge: true));
    QaLoggerService.instance.log('ADMIN',
        'GRANT_SKIN uid=${uid.substring(0, uid.length.clamp(0, 6))} skin=$skinId');
  }

  /// Increments an action-card count on the target user.
  /// [field] is one of: stunCardCount, guessBlock5Count, guessBlock10Count,
  /// blackoutCardCount.
  Future<void> grantCard({
    required String uid,
    required String field,
    required int count,
  }) async {
    await _userRef(uid).set({
      field: FieldValue.increment(count),
    }, SetOptions(merge: true));
    QaLoggerService.instance.log('ADMIN',
        'GRANT_CARD uid=${uid.substring(0, uid.length.clamp(0, 6))} field=$field count=$count');
  }
}
