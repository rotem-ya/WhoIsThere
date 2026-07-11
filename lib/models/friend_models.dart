import 'package:cloud_firestore/cloud_firestore.dart';

/// An accepted friend, stored at `users/{uid}/friends/{friendUid}`.
class FriendModel {
  final String uid;
  final String name;
  final String? photoUrl;
  final DateTime? since;

  const FriendModel({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.since,
  });

  factory FriendModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return FriendModel(
      uid: doc.id,
      name: (data['name'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      since: (data['since'] as Timestamp?)?.toDate(),
    );
  }
}

/// A pending friend request, stored at `friendRequests/{toUid}_{fromUid}`.
class FriendRequestModel {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final DateTime? createdAt;

  const FriendRequestModel({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    this.createdAt,
  });

  factory FriendRequestModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return FriendRequestModel(
      id: doc.id,
      fromUid: (data['fromUid'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A pending "join my game" invite, stored at `gameInvites/{toUid}_{fromUid}`.
class GameInviteModel {
  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String roomId;
  final String code;
  final DateTime? createdAt;

  const GameInviteModel({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.roomId,
    required this.code,
    this.createdAt,
  });

  factory GameInviteModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return GameInviteModel(
      id: doc.id,
      fromUid: (data['fromUid'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
      roomId: (data['roomId'] as String?) ?? '',
      code: (data['code'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A pending "join my group" invite, stored at `groupInvites/{toUid}_{groupId}`.
/// The recipient must accept before becoming a member — declining leaves the
/// group untouched, just like a WhatsApp group invite.
class GroupInviteModel {
  final String id;
  final String groupId;
  final String groupName;
  final String fromUid;
  final String fromName;
  final String toUid;
  final DateTime? createdAt;

  const GroupInviteModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    this.createdAt,
  });

  factory GroupInviteModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return GroupInviteModel(
      id: doc.id,
      groupId: (data['groupId'] as String?) ?? '',
      groupName: (data['groupName'] as String?) ?? 'קבוצה',
      fromUid: (data['fromUid'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// One row in the friends leaderboard: a friend (or me) and their cumulative
/// friends-game points.
class FriendScore {
  final String uid;
  final String name;
  final int points;
  final bool isMe;

  const FriendScore({
    required this.uid,
    required this.name,
    required this.points,
    this.isMe = false,
  });
}

/// A finished friends game, stored per participant at
/// `users/{uid}/friendGames/{roomId}`.
class FriendGameRecord {
  final String roomId;
  final DateTime? playedAt;
  final String winnerName;
  final List<({String name, int score})> scores; // sorted desc

  const FriendGameRecord({
    required this.roomId,
    required this.playedAt,
    required this.winnerName,
    required this.scores,
  });

  factory FriendGameRecord.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    final raw = (data['players'] as List?) ?? const [];
    final scores = raw
        .whereType<Map>()
        .map((m) => (
              name: (m['name'] as String?) ?? '',
              score: (m['score'] as int?) ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return FriendGameRecord(
      roomId: doc.id,
      playedAt: (data['playedAt'] as Timestamp?)?.toDate(),
      winnerName: (data['winnerName'] as String?) ?? '',
      scores: scores,
    );
  }
}

/// A saved friends squad ("קבוצה קבועה"): open a game for everyone in one tap,
/// keep a cumulative group scoreboard, and chat between games. Stored at
/// `groups/{groupId}`; messages under `groups/{groupId}/messages`.
class GroupModel {
  final String id;
  final String name;
  final String ownerUid;
  final List<String> memberUids;
  final Map<String, String> memberNames; // uid → display name (snapshot)
  final Map<String, int> points; // uid → cumulative group points
  final DateTime? createdAt;
  final DateTime? lastGameAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
    required this.memberNames,
    required this.points,
    this.createdAt,
    this.lastGameAt,
  });

  String nameOf(String uid) => memberNames[uid] ?? 'חבר';
  int pointsOf(String uid) => points[uid] ?? 0;

  factory GroupModel.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? const {};
    return GroupModel(
      id: doc.id,
      name: (data['name'] as String?) ?? 'קבוצה',
      ownerUid: (data['ownerUid'] as String?) ?? '',
      memberUids: List<String>.from(data['memberUids'] ?? const []),
      memberNames: Map<String, String>.from(data['memberNames'] ?? const {}),
      points: Map<String, int>.from(data['points'] ?? const {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastGameAt: (data['lastGameAt'] as Timestamp?)?.toDate(),
    );
  }
}
