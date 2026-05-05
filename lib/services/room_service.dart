import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/room_model.dart';
import '../models/player_model.dart';
import '../models/game_image_model.dart';
import '../core/constants/game_constants.dart';
import '../core/utils/room_code_generator.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rooms => _firestore.collection('rooms');

  static const double _letterCardBonusChance = 0.12;

  static const Set<String> _availableLocalPlaceIds = {
    'western_wall',
    'dome_of_the_rock',
    'tower_of_david',
    'mahane_yehuda_market',
    'knesset',
    'israel_museum',
    'yad_vashem',
    'masada',
    'dead_sea',
    'ein_gedi',
  };

  Future<List<GameImageModel>>? _localImagesFuture;

  Future<List<GameImageModel>> _loadLocalImages() {
    return _localImagesFuture ??= _readLocalImages();
  }

  Future<List<GameImageModel>> _readLocalImages() async {
    final rawJson = await rootBundle.loadString('assets/game_places/data/israel_places.json');
    final decoded = jsonDecode(rawJson);
    final rawPlaces = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic> ? decoded['places'] as List<dynamic>? : null);

    if (rawPlaces == null) return const [];

    return rawPlaces
        .whereType<Map<String, dynamic>>()
        .where((place) => place['is_active'] == true)
        .where((place) => _availableLocalPlaceIds.contains(place['id']))
        .map(_localPlaceToImage)
        .toList(growable: false);
  }

  GameImageModel _localPlaceToImage(Map<String, dynamic> place) {
    final id = (place['id'] ?? '').toString();
    final name = (place['name_he'] ?? '').toString();
    final answer = (place['answer_he'] ?? name).toString();
    final asset = (place['image_asset'] ?? 'assets/game_places/images/$id.jpg').toString();

    return GameImageModel(
      id: id,
      name: name,
      answer: answer,
      acceptedAnswers: List<String>.from(place['aliases_he'] ?? const []),
      category: ImageCategory.israeliLandmark,
      imageUrl: asset,
      thumbnailUrl: asset,
    );
  }

  Future<RoomModel> createRoom({
    required String hostId,
    required String hostName,
    String? hostPhotoUrl,
    int playerCount = 1,
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

    final players = <String, PlayerModel>{hostId: host};

    for (int i = 2; i <= playerCount; i++) {
      final virtualId = 'virtual_${i}_${docRef.id}';
      players[virtualId] = PlayerModel(
        id: virtualId,
        name: 'שחקן $i',
        score: 0,
        isBot: true,
      );
    }

    final room = RoomModel(
      id: docRef.id,
      code: code,
      hostId: hostId,
      players: players,
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

  Future<void> startGameDirectly(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);
    final images = await _loadLocalImages();
    if (images.isEmpty) return;
    final image = images[Random().nextInt(images.length)];
    await _rooms.doc(roomId).update({'selectedImageId': image.id});
    await _startGame(roomId, room, Difficulty.easy);
  }

  Future<void> castImageVote({
    required String roomId,
    required String userId,
    required String categoryName,
  }) async {
    await _rooms.doc(roomId).update({'imageVotes.$userId': categoryName});
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
    final images = await _loadLocalImages();
    if (images.isEmpty) return;

    final selectedImageId = images[Random().nextInt(images.length)].id;

    await _rooms.doc(roomId).update({
      'selectedImageId': selectedImageId,
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

    final hostVotedPieces = room.difficultyVotes[hostId];
    final selectedPieces = hostVotedPieces != null && winners.contains(hostVotedPieces)
        ? hostVotedPieces
        : winners[Random().nextInt(winners.length)];

    final difficulty = Difficulty.values.firstWhere(
      (d) => d.pieces == selectedPieces,
      orElse: () => Difficulty.easy,
    );

    await _startGame(roomId, room, difficulty);
  }

  Future<void> _startGame(String roomId, RoomModel room, Difficulty difficulty) async {
    final playerIds = room.players.keys.toList()..shuffle();
    final startScore = difficulty.startingPoints;

    final updatedPlayers = room.players.map(
      (id, player) => MapEntry(
        id,
        player.copyWith(score: startScore, letterCards: 0),
      ),
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
      'solvedLetters': [],
      'letterCardGrantedPlayerIds': [],
    });
  }

  Future<void> revealCell(String roomId, int index) async {
    await _rooms.doc(roomId).update({
      'placedPieces.${index.toString()}': 'revealed',
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

    if (!room.availablePieceIndices.contains(pieceIndex)) return;

    final player = room.players[userId];
    if (player == null) return;

    final newHidden = room.availablePieceIndices.where((i) => i != pieceIndex).toList();
    final newScore = player.score + difficulty.placePiecePoints;
    final shouldGrantLetterCard =
        player.letterCards == 0 &&
        !room.letterCardGrantedPlayerIds.contains(userId) &&
        Random().nextDouble() < _letterCardBonusChance;

    final updates = <String, dynamic>{
      'placedPieces.${pieceIndex.toString()}': userId,
      'availablePieceIndices': newHidden,
      'players.$userId.score': newScore,
    };

    if (shouldGrantLetterCard) {
      updates['players.$userId.letterCards'] = 1;
      updates['letterCardGrantedPlayerIds'] = FieldValue.arrayUnion([userId]);
    }

    await _rooms.doc(roomId).update(updates);
  }

  Future<void> skipPiecePlacement({required String roomId}) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);
    await _rooms.doc(roomId).update({
      'currentTurnIndex': room.currentTurnIndex + 1,
    });
  }

  Future<bool> submitAnswer({
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
        'players.$userId.score': FieldValue.increment(difficulty.winReward),
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': true},
        'guessCount': FieldValue.increment(1),
      });
      return true;
    }

    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);
    final currentScore = room.players[userId]?.score ?? 0;
    final newScore = currentScore - difficulty.wrongGuessPenalty;
    final nextTurnIndex = room.currentTurnIndex + 1;

    if (newScore <= 0) {
      await _rooms.doc(roomId).update({
        'players.$userId.score': 0,
        'players.$userId.isEliminated': true,
        'currentTurnIndex': nextTurnIndex,
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
        'guessCount': FieldValue.increment(1),
      });
      await _checkLastPlayerStanding(roomId);
    } else {
      await _rooms.doc(roomId).update({
        'players.$userId.score': newScore,
        'currentTurnIndex': nextTurnIndex,
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
        'guessCount': FieldValue.increment(1),
      });
    }
    return false;
  }

  Future<void> endGameNoWinner(String roomId) async {
    await _rooms.doc(roomId).update({
      'phase': GamePhase.finished.name,
    });
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

  Future<List<GameImageModel>> getPublicImages() => _loadLocalImages();

  Future<List<GameImageModel>> getAllImages() => _loadLocalImages();

  Future<GameImageModel?> getImage(String imageId) async {
    final images = await _loadLocalImages();
    return images.where((image) => image.id == imageId).cast<GameImageModel?>().firstOrNull ??
        (images.isNotEmpty ? images.first : null);
  }
}
