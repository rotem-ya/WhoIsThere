import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/friend_models.dart';
import '../models/room_model.dart';
import 'friends_service.dart';
import 'qa_logger_service.dart';

/// קבוצות חברים קבועות — a saved squad you can open a game for in one tap.
///
/// Firestore:
///   groups/{groupId}                     — GroupModel (members, cumulative points)
///   groups/{groupId}/messages/{id}       — persistent group chat
///   groups/{groupId}/games/{roomId}      — per-game score record (idempotency)
///   groupInvites/{toUid}_{groupId}       — a pending join invite (opt-in membership)
///
/// Group points mirror the friends-leaderboard pattern: every client records
/// only its OWN result per finished game (transaction-guarded per uid/room),
/// so no cross-user writes race each other.
///
/// Membership is opt-in, like a WhatsApp group invite: creating a group or
/// adding someone only sends them a [GroupInviteModel]. They become a member
/// (and the group becomes visible to them) only after [acceptGroupInvite];
/// [declineGroupInvite] just removes the invite, no membership created.
class GroupsService {
  GroupsService(this._db, this._friends);

  final FirebaseFirestore _db;
  final FriendsService _friends;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _groupInvites =>
      _db.collection('groupInvites');

  // ── ניהול קבוצה ─────────────────────────────────────────────────────────────

  /// Creates the group with just the owner as a member, then sends a join
  /// invite to each of [members] — they only become members once they accept
  /// (see [acceptGroupInvite]).
  Future<GroupModel> createGroup({
    required String name,
    required String myUid,
    required String myName,
    required List<FriendModel> members,
  }) async {
    final doc = _groups.doc();
    await doc.set({
      'name': name,
      'ownerUid': myUid,
      'memberUids': [myUid],
      'memberNames': {myUid: myName},
      'points': {myUid: 0},
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (final m in members) {
      await inviteMemberToGroup(
        groupId: doc.id,
        groupName: name,
        myUid: myUid,
        myName: myName,
        toUid: m.uid,
      );
    }
    QaLoggerService.instance
        .log('GROUP', 'CREATED id=${doc.id} invited=${members.length}');
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

  // ── הזמנה להצטרפות (WhatsApp-style opt-in) ──────────────────────────────────

  /// Invites [toUid] to join [groupId]. One pending invite per (recipient,
  /// group) — re-inviting overwrites the previous one. Fires a push via the
  /// onGroupInvite cloud function.
  Future<void> inviteMemberToGroup({
    required String groupId,
    required String groupName,
    required String myUid,
    required String myName,
    required String toUid,
  }) async {
    await _groupInvites.doc('${toUid}_$groupId').set({
      'groupId': groupId,
      'groupName': groupName,
      'fromUid': myUid,
      'fromName': myName,
      'toUid': toUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Pending group invites addressed to [uid].
  Stream<List<GroupInviteModel>> incomingGroupInvites(String uid) =>
      _groupInvites
          .where('toUid', isEqualTo: uid)
          .snapshots()
          .map((s) => s.docs.map(GroupInviteModel.fromDoc).toList());

  /// Accepts [invite]: adds the recipient as a member (only now do they see
  /// the group), then removes the invite. Returns false (and just cleans up
  /// the stale invite) if the group was deleted in the meantime.
  Future<bool> acceptGroupInvite(GroupInviteModel invite, String myName) async {
    final groupDoc = await _groups.doc(invite.groupId).get();
    if (!groupDoc.exists) {
      await _groupInvites.doc(invite.id).delete();
      return false;
    }
    await _groups.doc(invite.groupId).update({
      'memberUids': FieldValue.arrayUnion([invite.toUid]),
      'memberNames.${invite.toUid}': myName,
      'points.${invite.toUid}': 0,
    });
    await _groupInvites.doc(invite.id).delete();
    QaLoggerService.instance
        .log('GROUP', 'INVITE_ACCEPTED group=${invite.groupId}');
    return true;
  }

  /// Declines [invite]: just removes it, no membership is created.
  Future<void> declineGroupInvite(GroupInviteModel invite) =>
      _groupInvites.doc(invite.id).delete();

  // ── משחק קבוצתי בלחיצה ──────────────────────────────────────────────────────

  /// Invites group members (except me) to [room] — each invite doc fires
  /// the existing FCM cloud function, so everyone invited gets a push with a
  /// one-tap join. [toUids] limits the invite to a chosen subset (null =
  /// the whole squad). Also stamps the group's lastGameAt.
  Future<void> inviteGroupToRoom({
    required GroupModel group,
    required RoomModel room,
    required String myUid,
    required String myName,
    List<String>? toUids,
  }) async {
    final targets = toUids ?? group.memberUids;
    for (final uid in targets) {
      if (uid == myUid) continue;
      if (!group.memberUids.contains(uid)) continue;
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
        'INVITED group=${group.id} invited=${targets.where((u) => u != myUid).length} room=${room.id.substring(0, 6)}');
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
