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
      facts: List<String>.from(place['facts'] ?? const []),
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

    if (room.players.containsKey(userId)) {
      final updates = <String, dynamic>{'players.$userId.name': userName};
      if (userPhotoUrl != null) updates['players.$userId.photoUrl'] = userPhotoUrl;
      await doc.reference.update(updates);
      return RoomModel.fromFirestore(await doc.reference.get());
    }

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

  Future<RoomModel?> findRoomByCode(String code) async {
    final query = await _rooms
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return RoomModel.fromFirestore(query.docs.first);
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
    final image = await _pickSmartImage(images, room.players);
    await _rooms.doc(roomId).update({'selectedImageId': image.id});
    await _startGame(roomId, room, Difficulty.easy);
    _recordExposureForAll(room.players, image.id);
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

    final image = await _pickSmartImage(images, room.players);

    await _rooms.doc(roomId).update({
      'selectedImageId': image.id,
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
    final imageId = room.selectedImageId;
    if (imageId != null && imageId.isNotEmpty) {
      _recordExposureForAll(room.players, imageId);
    }
  }

  // ── Exposure history helpers ──────────────────────────────────

  Future<GameImageModel> _pickSmartImage(
    List<GameImageModel> images,
    Map<String, PlayerModel> players,
  ) async {
    final realIds = players.entries
        .where((e) => !e.value.isBot)
        .map((e) => e.key)
        .toList();

    if (realIds.isEmpty) return images[Random().nextInt(images.length)];

    try {
      final exposureMaps = await Future.wait(realIds.map(_getExposureCounts));

      final totals = <String, int>{};
      for (final map in exposureMaps) {
        for (final entry in map.entries) {
          totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
        }
      }

      final unseen = images.where((img) => (totals[img.id] ?? 0) == 0).toList();
      if (unseen.isNotEmpty) return unseen[Random().nextInt(unseen.length)];

      final sorted = [...images]
        ..sort((a, b) => (totals[a.id] ?? 0).compareTo(totals[b.id] ?? 0));
      return sorted.first;
    } catch (_) {
      return images[Random().nextInt(images.length)];
    }
  }

  Future<Map<String, int>> _getExposureCounts(String uid) async {
    try {
      final snap = await _firestore.doc('users/$uid/exposure_history').get();
      if (!snap.exists) return {};
      final data = snap.data() ?? {};
      return data.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
    } catch (_) {
      return {};
    }
  }

  void _recordExposureForAll(Map<String, PlayerModel> players, String imageId) {
    for (final entry in players.entries) {
      if (!entry.value.isBot) {
        _firestore.doc('users/${entry.key}/exposure_history').set(
          {imageId: FieldValue.increment(1)},
          SetOptions(merge: true),
        ).ignore();
      }
    }
  }

  Future<void> _startGame(String roomId, RoomModel room, Difficulty difficulty) async {
    final playerIds = room.players.keys.toList()..shuffle();
    final startScore = difficulty.startingPoints;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

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
      'turnPhase': TurnPhase.revealTurn.name,
      'revealDeadlineMs': nowMs + 8000,
      'guessOpportunityPlayerId': null,
      'guessModePlayerId': null,
      'lastRevealedByPlayerId': null,
      'guessOpportunityDeadlineMs': null,
      'guessModeDeadlineMs': null,
      'wrongGuessCounts': {},
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Determine who gets the guess opportunity.
    // Solo (1 human player): revealer gets their own guess opportunity.
    // Multiplayer: next active player in turn order gets the opportunity.
    final humanCount = room.players.values.where((p) => !p.isBot).length;
    final isSolo = humanCount == 1;
    final String guessOpportunityPlayerId;
    if (isSolo) {
      guessOpportunityPlayerId = userId;
    } else {
      final activeTurnOrder = room.turnOrder
          .where((id) => !(room.players[id]?.isEliminated ?? false))
          .toList();
      final revealerIdx = activeTurnOrder.indexOf(userId);
      if (revealerIdx >= 0 && activeTurnOrder.isNotEmpty) {
        guessOpportunityPlayerId =
            activeTurnOrder[(revealerIdx + 1) % activeTurnOrder.length];
      } else {
        guessOpportunityPlayerId = userId;
      }
    }

    final updates = <String, dynamic>{
      'placedPieces.${pieceIndex.toString()}': userId,
      'availablePieceIndices': newHidden,
      'players.$userId.score': newScore,
      'turnPhase': TurnPhase.guessOpportunity.name,
      'guessOpportunityPlayerId': guessOpportunityPlayerId,
      'guessOpportunityDeadlineMs': nowMs + 7000,
      'lastRevealedByPlayerId': userId,
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _rooms.doc(roomId).update({
      'currentTurnIndex': room.currentTurnIndex + 1,
      'turnPhase': TurnPhase.revealTurn.name,
      'revealDeadlineMs': nowMs + 8000,
      'guessOpportunityPlayerId': null,
      'guessModePlayerId': null,
      'guessOpportunityDeadlineMs': null,
      'guessModeDeadlineMs': null,
    });
  }

  /// Called by the player who has the guess opportunity to lock in as the guesser.
  /// Returns true if the transition succeeded.
  Future<bool> enterGuessMode({
    required String roomId,
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool success = false;

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(_rooms.doc(roomId));
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);

      if (room.turnPhase != TurnPhase.guessOpportunity) return;
      if (room.guessOpportunityPlayerId != userId) return;
      final deadline = room.guessOpportunityDeadlineMs;
      if (deadline != null && now >= deadline) return;

      tx.update(_rooms.doc(roomId), {
        'turnPhase': TurnPhase.guessMode.name,
        'guessModePlayerId': userId,
        'guessModeDeadlineMs': now + 20000,
      });
      success = true;
    });

    return success;
  }

  /// Called by the current-turn player when the reveal timer expires.
  /// Advances the turn and resets to revealTurn.
  Future<void> advanceTurnOnTimeout({
    required String roomId,
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(_rooms.doc(roomId));
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);

      if (room.turnPhase != TurnPhase.revealTurn) return;
      if (room.currentTurnUserId != userId) return;
      final deadline = room.revealDeadlineMs;
      if (deadline == null || now < deadline) return;

      tx.update(_rooms.doc(roomId), {
        'currentTurnIndex': room.currentTurnIndex + 1,
        'turnPhase': TurnPhase.revealTurn.name,
        'revealDeadlineMs': now + 8000,
        'guessOpportunityPlayerId': null,
        'guessModePlayerId': null,
        'guessOpportunityDeadlineMs': null,
        'guessModeDeadlineMs': null,
      });
    });
  }

  /// Called when the guess mode timer expires without a submission.
  /// Applies a penalty (Phase D), advances the turn, resets to revealTurn.
  Future<void> expireGuessMode({required String roomId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(_rooms.doc(roomId));
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);

      if (room.turnPhase != TurnPhase.guessMode) return;
      final deadline = room.guessModeDeadlineMs;
      if (deadline == null || now < deadline) return;

      // TODO Phase D: apply wallet penalty for room.guessModePlayerId

      tx.update(_rooms.doc(roomId), {
        'currentTurnIndex': room.currentTurnIndex + 1,
        'turnPhase': TurnPhase.revealTurn.name,
        'revealDeadlineMs': now + 8000,
        'guessModePlayerId': null,
        'guessOpportunityPlayerId': null,
        'guessOpportunityDeadlineMs': null,
        'guessModeDeadlineMs': null,
      });
    });
  }

  Future<bool> submitAnswer({
    required String roomId,
    required String userId,
    required String guess,
    required GameImageModel image,
    required Difficulty difficulty,
  }) async {
    // Read current room state for guard and score lookup
    final roomDoc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(roomDoc);

    // Guard: only the designated guesser in guessMode may submit
    if (room.turnPhase != TurnPhase.guessMode || room.guessModePlayerId != userId) {
      return false;
    }

    final isCorrect = image.isCorrectAnswer(guess);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (isCorrect) {
      await _rooms.doc(roomId).update({
        'phase': GamePhase.finished.name,
        'winnerId': userId,
        'players.$userId.score': FieldValue.increment(difficulty.winReward),
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': true},
        'guessCount': FieldValue.increment(1),
        'turnPhase': TurnPhase.roundOver.name,
        'guessModePlayerId': null,
      });
      return true;
    }

    final currentScore = room.players[userId]?.score ?? 0;
    final newScore = currentScore - difficulty.wrongGuessPenalty;
    final nextTurnIndex = room.currentTurnIndex + 1;
    final currentWrongCount = room.wrongGuessCounts[userId] ?? 0;

    final updates = <String, dynamic>{
      'currentTurnIndex': nextTurnIndex,
      'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
      'guessCount': FieldValue.increment(1),
      'turnPhase': TurnPhase.revealTurn.name,
      'revealDeadlineMs': nowMs + 8000,
      'guessModePlayerId': null,
      'guessOpportunityPlayerId': null,
      'guessOpportunityDeadlineMs': null,
      'guessModeDeadlineMs': null,
      'wrongGuessCounts.$userId': currentWrongCount + 1,
    };

    if (newScore <= 0) {
      updates['players.$userId.score'] = 0;
      updates['players.$userId.isEliminated'] = true;
      await _rooms.doc(roomId).update(updates);
      await _checkLastPlayerStanding(roomId);
    } else {
      updates['players.$userId.score'] = newScore;
      await _rooms.doc(roomId).update(updates);
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
