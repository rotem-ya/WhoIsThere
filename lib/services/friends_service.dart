import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
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
  CollectionReference<Map<String, dynamic>> get _gameInvites =>
      _db.collection('gameInvites');
  CollectionReference<Map<String, dynamic>> get _dms =>
      _db.collection('directMessages');

  /// Stable conversation id for a pair of users (order-independent).
  String _convoId(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

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

  /// The user's accepted friends. The subcollection doc's `name` is a
  /// SNAPSHOT taken once at friendship time (_linkFriendship) — it never
  /// updates if the friend later renames (e.g. a guest named "אורח131"
  /// signs into a real account and picks "קובי"). Re-resolve each friend's
  /// CURRENT name from their live user doc, the same way [leaderboard]
  /// already does, so a renamed friend doesn't look like they "vanished"
  /// while actually just showing under their old name.
  Stream<List<FriendModel>> friends(String uid) => _users
      .doc(uid)
      .collection('friends')
      .snapshots()
      .asyncMap((s) async {
    final base = s.docs.map(FriendModel.fromDoc).toList();
    if (base.isEmpty) return base;

    final liveNames = <String, String>{};
    final uids = base.map((f) => f.uid).toList();
    for (var i = 0; i < uids.length; i += 10) {
      final chunk = uids.sublist(i, min(i + 10, uids.length));
      final snap = await _users.where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        final n = d.data()['name'] as String?;
        if (n != null && n.isNotEmpty) liveNames[d.id] = n;
      }
    }

    return base.map((f) {
      final live = liveNames[f.uid];
      if (live == null || live == f.name) return f;
      return FriendModel(uid: f.uid, name: live, photoUrl: f.photoUrl, since: f.since);
    }).toList();
  });

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

  // ── Game invites ────────────────────────────────────────────────────────────

  /// Invites [toUid] to join the room the host just created. One pending invite
  /// per (recipient, sender) — re-inviting overwrites the previous one.
  Future<void> sendGameInvite({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String roomId,
    required String code,
  }) async {
    await _gameInvites.doc('${toUid}_$fromUid').set({
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'roomId': roomId,
      'code': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Pending game invites addressed to [uid].
  Stream<List<GameInviteModel>> incomingGameInvites(String uid) => _gameInvites
      .where('toUid', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map(GameInviteModel.fromDoc).toList());

  Future<void> deleteGameInvite(String id) => _gameInvites.doc(id).delete();

  // ── Direct messages (friend-to-friend chat, outside a game) ─────────────────

  /// Sends a direct message from [myUid] to [friendUid]. Capped at 300 chars.
  Future<void> sendDirectMessage({
    required String myUid,
    required String myName,
    required String friendUid,
    required String text,
  }) async {
    var body = text.trim();
    if (body.isEmpty) return;
    if (body.length > 300) body = body.substring(0, 300);
    await _dms.doc(_convoId(myUid, friendUid)).collection('messages').add({
      'senderId': myUid,
      'senderName': myName,
      'text': body,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Live message feed for the conversation between [myUid] and [friendUid]
  /// (oldest → newest), reusing the shared [ChatMessage] model.
  Stream<List<ChatMessage>> directMessages(String myUid, String friendUid) => _dms
      .doc(_convoId(myUid, friendUid))
      .collection('messages')
      .orderBy('ts', descending: true)
      .limit(80)
      .snapshots()
      .map((s) => s.docs
          .map((d) => ChatMessage.fromMap(d.id, d.data()))
          .toList()
          .reversed
          .toList());
}
