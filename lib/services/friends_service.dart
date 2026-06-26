import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/friend_models.dart';
import '../models/room_model.dart';

/// A user-facing error with a Hebrew message safe to show in a snackbar.
class FriendException implements Exception {
  final String message;
  FriendException(this.message);
  @override
  String toString() => message;
}

/// Social layer: personal friend codes, friend requests, the friends list, the
/// cumulative friends leaderboard, and per-game history.
///
/// Firestore layout:
///   users/{uid}.friendCode            short shareable code
///   users/{uid}.friendsGamePoints     cumulative points across friends games
///   users/{uid}/friends/{friendUid}   accepted friend (written on both sides)
///   users/{uid}/friendGames/{roomId}  one finished friends game (per player)
///   friendRequests/{toUid}_{fromUid}  a pending request
class FriendsService {
  FriendsService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('friendRequests');

  // Unambiguous alphabet (no 0/O/1/I) for readable, shareable codes.
  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _randomCode([int len = 6]) {
    final rnd = Random.secure();
    return List.generate(len, (_) => _alphabet[rnd.nextInt(_alphabet.length)])
        .join();
  }

  /// Returns the user's friend code, generating and persisting a unique one on
  /// first use.
  Future<String> ensureFriendCode(String uid) async {
    final doc = await _users.doc(uid).get();
    final existing = doc.data()?['friendCode'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    // Try a few times to avoid the (rare) collision.
    for (var attempt = 0; attempt < 6; attempt++) {
      final code = _randomCode();
      final clash =
          await _users.where('friendCode', isEqualTo: code).limit(1).get();
      if (clash.docs.isEmpty) {
        await _users.doc(uid).set({'friendCode': code}, SetOptions(merge: true));
        return code;
      }
    }
    // Fallback: longer code is collision-safe enough to skip the check.
    final fallback = _randomCode(8);
    await _users.doc(uid).set({'friendCode': fallback}, SetOptions(merge: true));
    return fallback;
  }

  /// Sends a friend request to the owner of [code]. Throws [FriendException]
  /// with a Hebrew message on any user-correctable problem.
  Future<void> sendRequestByCode({
    required String myUid,
    required String myName,
    required String code,
  }) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) throw FriendException('הזן קוד חבר');

    final found =
        await _users.where('friendCode', isEqualTo: clean).limit(1).get();
    if (found.docs.isEmpty) {
      throw FriendException('לא נמצא משתמש עם הקוד הזה');
    }
    final target = found.docs.first;
    final toUid = target.id;
    if (toUid == myUid) throw FriendException('זה הקוד שלך 🙂');

    // Already friends?
    final already = await _users.doc(myUid).collection('friends').doc(toUid).get();
    if (already.exists) throw FriendException('אתם כבר חברים');

    final toName = (target.data()['name'] as String?) ?? 'שחקן';

    // If THEY already asked ME, accept directly instead of a second request.
    final incoming = await _requests.doc('${myUid}_$toUid').get();
    if (incoming.exists) {
      await _linkFriendship(myUid, myName, toUid, toName);
      await _requests.doc('${myUid}_$toUid').delete();
      return;
    }

    await _requests.doc('${toUid}_$myUid').set({
      'fromUid': myUid,
      'fromName': myName,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Incoming pending requests for [uid].
  Stream<List<FriendRequestModel>> incomingRequests(String uid) => _requests
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(FriendRequestModel.fromDoc).toList());

  /// The user's accepted friends.
  Stream<List<FriendModel>> friends(String uid) => _users
      .doc(uid)
      .collection('friends')
      .snapshots()
      .map((s) => s.docs.map(FriendModel.fromDoc).toList());

  Future<void> acceptRequest(FriendRequestModel req, String myName) async {
    await _linkFriendship(req.toUid, myName, req.fromUid, req.fromName);
    await _requests.doc(req.id).delete();
  }

  Future<void> declineRequest(FriendRequestModel req) =>
      _requests.doc(req.id).delete();

  Future<void> removeFriend(String myUid, String friendUid) async {
    await _users.doc(myUid).collection('friends').doc(friendUid).delete();
    await _users.doc(friendUid).collection('friends').doc(myUid).delete();
  }

  /// Writes the friendship document on both users' sides.
  Future<void> _linkFriendship(
      String aUid, String aName, String bUid, String bName) async {
    final now = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.set(_users.doc(aUid).collection('friends').doc(bUid),
        {'name': bName, 'since': now});
    batch.set(_users.doc(bUid).collection('friends').doc(aUid),
        {'name': aName, 'since': now});
    await batch.commit();
  }

  /// Cumulative friends leaderboard: me + my friends, sorted by points desc.
  Future<List<FriendScore>> leaderboard({
    required String myUid,
    required String myName,
    required int myPoints,
  }) async {
    final friendDocs =
        await _users.doc(myUid).collection('friends').get();
    final friendUids = friendDocs.docs.map((d) => d.id).toList();

    final rows = <FriendScore>[
      FriendScore(uid: myUid, name: myName, points: myPoints, isMe: true),
    ];

    // Read friends' user docs in chunks of 10 (whereIn limit).
    for (var i = 0; i < friendUids.length; i += 10) {
      final chunk = friendUids.sublist(i, min(i + 10, friendUids.length));
      if (chunk.isEmpty) continue;
      final snap = await _users
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        rows.add(FriendScore(
          uid: d.id,
          name: (data['name'] as String?) ?? 'שחקן',
          points: (data['friendsGamePoints'] as int?) ?? 0,
        ));
      }
    }
    rows.sort((a, b) => b.points.compareTo(a.points));
    return rows;
  }

  /// Recent friends games for [uid], newest first.
  Stream<List<FriendGameRecord>> recentGames(String uid, {int limit = 20}) =>
      _users
          .doc(uid)
          .collection('friendGames')
          .orderBy('playedAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(FriendGameRecord.fromDoc).toList());

  /// Records a finished friends game for the CALLING user only: appends the
  /// per-game record and adds the player's own score to their cumulative total.
  /// Each client records its own result (Firestore rules only allow writing
  /// your own user doc). Idempotent per (player, room) — re-running never
  /// double-counts. Best-effort; failures are swallowed so the win flow is
  /// never blocked.
  Future<void> recordMyResult({required RoomModel room, required String myUid}) async {
    if (!room.isFriendsGame) return;
    final humans =
        room.players.values.where((p) => !p.isBot).toList(growable: false);
    if (humans.length < 2) return; // a solo friends game has no rivals to score
    final me = room.players[myUid];
    if (me == null || me.isBot) return;

    final playersPayload = humans
        .map((p) => {'uid': p.id, 'name': p.name, 'score': p.score})
        .toList();
    final winnerName = room.winnerId == null
        ? ''
        : (room.players[room.winnerId]?.name ?? '');

    final ref = _users.doc(myUid).collection('friendGames').doc(room.id);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        if (existing.exists) return; // already recorded for me
        tx.set(ref, {
          'playedAt': FieldValue.serverTimestamp(),
          'winnerId': room.winnerId,
          'winnerName': winnerName,
          'players': playersPayload,
          'myScore': me.score,
        });
        tx.set(_users.doc(myUid),
            {'friendsGamePoints': FieldValue.increment(me.score)},
            SetOptions(merge: true));
      });
    } catch (_) {
      // Best-effort; never block the win flow on a scoreboard write.
    }
  }
}
