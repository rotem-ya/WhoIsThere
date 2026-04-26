import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room_model.dart';
import '../models/player_model.dart';
import '../models/game_image_model.dart';
import '../core/constants/game_constants.dart';
import '../core/utils/room_code_generator.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rooms => _firestore.collection('rooms');

  Future<RoomModel> createRoom({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
  }) async {
    final code = RoomCodeGenerator.generate();
    final docRef = _rooms.doc();

    final host = PlayerModel(
      id: hostId,
      name: hostName,
      photoUrl: hostPhotoUrl,
      score: 0,
      isHost: true,
    );

    final room = RoomModel(
      id: docRef.id,
      code: code,
      hostId: hostId,
      players: {hostId: host},
      createdAt: DateTime.now(),
    );

    await docRef.set(room.toMap());
    return room;
  }

  Future<RoomModel?> joinRoom({
    required String code,
    required String userId,
    required String userName,
    String? userPhotoUrl,
  }) async {
    final query = await _rooms
        .where('code', isEqualTo: code.toUpperCase())
        .where('phase', isEqualTo: GamePhase.waiting.name)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    final room = RoomModel.fromFirestore(doc);

    if (room.players.length >= GameConstants.maxPlayers) return null;
    if (room.players.containsKey(userId)) return room;

    final newPlayer = PlayerModel(
      id: userId,
      name: userName,
      photoUrl: userPhotoUrl,
      score: 0,
    );

    await doc.reference.update({
      'players.$userId': newPlayer.toMap(),
    });

    return RoomModel.fromFirestore(await doc.reference.get());
  }

  Stream<RoomModel?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map(
          (doc) => doc.exists ? RoomModel.fromFirestore(doc) : null,
        );
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return;

    final room = RoomModel.fromFirestore(doc);

    if (room.players.length <= 1) {
      await _rooms.doc(roomId).delete();
      return;
    }

    await _rooms.doc(roomId).update({
      'players.$userId': FieldValue.delete(),
    });

    // Transfer host if needed
    if (room.hostId == userId) {
      final newHostId = room.players.keys.firstWhere((id) => id != userId);
      await _rooms.doc(roomId).update({
        'hostId': newHostId,
        'players.$newHostId.isHost': true,
      });
    }
  }

  Future<void> startVotingImage(String roomId) async {
    await _rooms.doc(roomId).update({'phase': GamePhase.votingImage.name});
  }

  Future<void> castImageVote({
    required String roomId,
    required String userId,
    required String imageId,
  }) async {
    await _rooms.doc(roomId).update({'imageVotes.$userId': imageId});
  }

  Future<void> castDifficultyVote({
    required String roomId,
    required String userId,
    required Difficulty difficulty,
  }) async {
    await _rooms.doc(roomId).update({
      'difficultyVotes.$userId': difficulty.pieces,
    });
  }

  Future<void> resolveImageVote(String roomId, String hostId) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);

    final tally = <String, int>{};
    for (final entry in room.imageVotes.entries) {
      final weight = entry.key == hostId
          ? GameConstants.hostVoteWeight
          : GameConstants.regularVoteWeight;
      tally[entry.value] = (tally[entry.value] ?? 0) + weight;
    }

    if (tally.isEmpty) return;

    final maxVotes = tally.values.reduce(max);
    final winners = tally.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    // Tie → host's vote wins; otherwise random among tied
    String selected;
    if (room.imageVotes.containsKey(hostId) && winners.contains(room.imageVotes[hostId])) {
      selected = room.imageVotes[hostId]!;
    } else {
      selected = winners[Random().nextInt(winners.length)];
    }

    await _rooms.doc(roomId).update({
      'selectedImageId': selected,
      'phase': GamePhase.votingDifficulty.name,
    });
  }

  Future<void> resolveDifficultyVote(String roomId, String hostId) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);

    final tally = <int, int>{};
    for (final entry in room.difficultyVotes.entries) {
      final weight = entry.key == hostId
          ? GameConstants.hostVoteWeight
          : GameConstants.regularVoteWeight;
      tally[entry.value] = (tally[entry.value] ?? 0) + weight;
    }

    if (tally.isEmpty) return;

    final maxVotes = tally.values.reduce(max);
    final winners = tally.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    int selectedPieces;
    final hostVotedPieces = room.difficultyVotes[hostId];
    if (hostVotedPieces != null && winners.contains(hostVotedPieces)) {
      selectedPieces = hostVotedPieces;
    } else {
      selectedPieces = winners[Random().nextInt(winners.length)];
    }

    final difficulty = Difficulty.values.firstWhere(
      (d) => d.pieces == selectedPieces,
      orElse: () => Difficulty.easy,
    );

    await _startGame(roomId, room, difficulty);
  }

  Future<void> _startGame(
      String roomId, RoomModel room, Difficulty difficulty) async {
    final playerIds = room.players.keys.toList()..shuffle();
    final startScore = difficulty.startingPoints;

    final updatedPlayers = room.players.map(
      (id, player) => MapEntry(id, player.copyWith(score: startScore)),
    );

    final totalCells = difficulty.gridSize * difficulty.gridSize;
    final allCells = List.generate(totalCells, (i) => i);

    await _rooms.doc(roomId).update({
      'phase': GamePhase.playing.name,
      'selectedDifficulty': difficulty.name,
      'turnOrder': playerIds,
      'currentTurnIndex': 0,
      'players': updatedPlayers.map((k, v) => MapEntry(k, v.toMap())),
      'placedPieces': {},
      'availablePieceIndices': allCells,
    });
  }

  Future<void> revealPiece({
    required String roomId,
    required String userId,
    required int pieceIndex,
    required Difficulty difficulty,
  }) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);

    final newHidden = room.availablePieceIndices.where((i) => i != pieceIndex).toList();
    final newScore = (room.players[userId]?.score ?? 0) + difficulty.placePiecePoints;

    await _rooms.doc(roomId).update({
      'placedPieces.${pieceIndex.toString()}': userId,
      'availablePieceIndices': newHidden,
      'players.$userId.score': newScore,
    });
  }

  Future<void> skipPiecePlacement({
    required String roomId,
  }) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);
    await _rooms.doc(roomId).update({
      'currentTurnIndex': room.currentTurnIndex + 1,
    });
  }

  Future<bool> makeGuess({
    required String roomId,
    required String userId,
    required String guess,
    required GameImageModel image,
    required Difficulty difficulty,
  }) async {
    final isCorrect = image.isCorrectAnswer(guess);

    if (isCorrect) {
      await _rooms.doc(roomId).update({
        'phase': GamePhase.finished.name,
        'winnerId': userId,
        'players.$userId.score':
            FieldValue.increment(difficulty.winReward),
      });
    } else {
      final doc = await _rooms.doc(roomId).get();
      final room = RoomModel.fromFirestore(doc);
      final currentScore = room.players[userId]?.score ?? 0;
      final newScore = currentScore - difficulty.wrongGuessPenalty;

      if (newScore <= 0) {
        await _rooms.doc(roomId).update({
          'players.$userId.score': 0,
          'players.$userId.isEliminated': true,
        });
        await _checkLastPlayerStanding(roomId);
      } else {
        await _rooms.doc(roomId).update({
          'players.$userId.score': newScore,
        });
      }
    }

    return isCorrect;
  }

  Future<void> _checkLastPlayerStanding(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);
    final active = room.activePlayers;

    if (active.length == 1) {
      await _rooms.doc(roomId).update({
        'phase': GamePhase.finished.name,
        'winnerId': active.first.id,
      });
    }
  }

  Future<List<GameImageModel>> getPublicImages() async {
    final query = await _firestore
        .collection('images')
        .where('isPremium', isEqualTo: false)
        .get();
    return query.docs.map(GameImageModel.fromFirestore).toList();
  }

  Future<List<GameImageModel>> getAllImages() async {
    final query = await _firestore.collection('images').get();
    return query.docs.map(GameImageModel.fromFirestore).toList();
  }

  Future<GameImageModel?> getImage(String imageId) async {
    final doc = await _firestore.collection('images').doc(imageId).get();
    if (!doc.exists) return null;
    return GameImageModel.fromFirestore(doc);
  }
}
