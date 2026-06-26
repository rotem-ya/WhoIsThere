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
