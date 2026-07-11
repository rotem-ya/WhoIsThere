import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/friend_models.dart';
import '../models/room_model.dart';
import 'friends_service.dart';
import 'qa_logger_service.dart';

/// קבוצות חברים קבועות — a saved squad you can open a game for in one tap.
///
/// Firestore:
///   groups/{groupId}                — GroupModel (members, cumulative points)
///   groups/{groupId}/messages/{id}  — persistent group chat
///   groups/{groupId}/games/{roomId} — per-game score record (idempotency)
///
/// Group points mirror the friends-leaderboard pattern: every client records
/// only its OWN result per finished game (transaction-guarded per uid/room),
/// so no cross-user writes race each other.
class GroupsService {
  GroupsService(this._db, this._friends);

  final FirebaseFirestore _db;
  final FriendsService _friends;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  // ── ניהול קבוצה ─────────────────────────────────────────────────────────────

  Future<GroupModel> createGroup({
    required String name,
    required String myUid,
    required String myName,
    required List<FriendModel> members,
  }) async {
    final doc = _groups.doc();
    final memberUids = <String>[myUid, ...members.map((m) => m.uid)];
    final memberNames = <String, String>{
      myUid: myName,
      for (final m in members) m.uid: m.name,
    };
    await doc.set({
      'name': name,
      'ownerUid': myUid,
      'memberUids': memberUids,
      'memberNames': memberNames,
      'points': {for (final uid in memberUids) uid: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
    QaLoggerService.instance
        .log('GROUP', 'CREATED id=${doc.id} members=${memberUids.length}');
    final snap = await doc.get();
    return GroupModel.fromDoc(snap);
  }

  Future<void> deleteGroup(String groupId) => _groups.doc(groupId).delete();

  Future<void> leaveGroup(
      {required String groupId, required String myUid}) async {
    await _groups.doc(groupId).update({
      'memberUids': FieldValue.arrayRemove([myUid]),
      'memberNames.$myUid': FieldValue.delete(),
      'points.$myUid': FieldValue.delete(),
    });
  }

  /// Groups I'm a member of, most recently played first.
  Stream<List<GroupModel>> myGroups(String uid) => _groups
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(GroupModel.fromDoc).toList()
        ..sort((a, b) => (b.lastGameAt ?? b.createdAt ?? DateTime(2000))
            .compareTo(a.lastGameAt ?? a.createdAt ?? DateTime(2000))));

  // ── משחק קבוצתי בלחיצה ──────────────────────────────────────────────────────

  /// Invites every group member (except me) to [room] — each invite doc fires
  /// the existing FCM cloud function, so the whole squad gets a push with a
  /// one-tap join. Also stamps the group's lastGameAt.
  Future<void> inviteGroupToRoom({
    required GroupModel group,
    required RoomModel room,
    required String myUid,
    required String myName,
  }) async {
    for (final uid in group.memberUids) {
      if (uid == myUid) continue;
      await _friends.sendGameInvite(
        fromUid: myUid,
        fromName: myName,
        toUid: uid,
        roomId: room.id,
        code: room.code,
      );
    }
    await _groups
        .doc(group.id)
        .set({'lastGameAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
    QaLoggerService.instance.log('GROUP',
        'INVITED group=${group.id} members=${group.memberUids.length - 1} room=${room.id.substring(0, 6)}');
  }

  // ── ניקוד מצטבר ─────────────────────────────────────────────────────────────

  /// Adds MY score from a finished group game to the group's cumulative
  /// scoreboard. Idempotent per player/room via groups/{id}/games/{roomId}.
  Future<void> recordMyGroupResult({
    required RoomModel room,
    required String myUid,
  }) async {
    final groupId = room.groupId;
    if (groupId == null || groupId.isEmpty) return;
    final me = room.players[myUid];
    if (me == null || me.isBot) return;

    final gameRef = _groups.doc(groupId).collection('games').doc(room.id);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(gameRef);
        final recorded =
            List<String>.from(existing.data()?['recordedUids'] ?? const []);
        if (recorded.contains(myUid)) return; // already counted for me
        tx.set(
            gameRef,
            {
              'recordedUids': FieldValue.arrayUnion([myUid]),
              'scores.$myUid': me.score,
              'winnerName': room.winnerId == null
                  ? ''
                  : (room.players[room.winnerId]?.name ?? ''),
              'playedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        tx.set(
            _groups.doc(groupId),
            {'points.$myUid': FieldValue.increment(me.score)},
            SetOptions(merge: true));
      });
      QaLoggerService.instance.log(
          'GROUP', 'RESULT_RECORDED group=$groupId score=${me.score}');
    } catch (e) {
      QaLoggerService.instance.log('GROUP', 'RESULT_RECORD_ERROR $e');
    }
  }

  // ── צ'אט קבוצתי ─────────────────────────────────────────────────────────────

  // Same schema as the in-game room chat, so the shared ChatSheet widget
  // renders group chat unchanged.
  Future<void> sendMessage({
    required String groupId,
    required String senderUid,
    required String senderName,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _groups.doc(groupId).collection('messages').add({
      'senderId': senderUid,
      'senderName': senderName,
      'text': t.length > 300 ? t.substring(0, 300) : t,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Stream<List<ChatMessage>> messages(String groupId) => _groups
      .doc(groupId)
      .collection('messages')
      .orderBy('ts', descending: false)
      .limitToLast(60)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => ChatMessage.fromMap(d.id, d.data())).toList());
}
