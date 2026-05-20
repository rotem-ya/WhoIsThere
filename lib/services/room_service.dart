import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

import '../models/economy/economy_transaction_model.dart';
import '../models/economy/user_economy_model.dart';
import '../models/room_model.dart';
import '../models/player_model.dart';
import '../models/game_image_model.dart';
import '../core/constants/economy_config.dart';
import '../core/constants/game_constants.dart';
import '../core/utils/room_code_generator.dart';
import 'qa_logger_service.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rooms => _firestore.collection('rooms');

  static const _uuid = Uuid();

  DocumentReference _walletRef(String uid) =>
      _firestore.doc('users/$uid/economy/wallet');

  DocumentReference _txRef(String uid, String txId) =>
      _firestore.doc('users/$uid/economy_transactions/$txId');

  static const double _letterCardBonusChance = 0.12;

  // Returns reveal timer duration in ms based on how much of the board is open.
  static int _revealTimerMs(int revealedCount, int totalTiles) {
    final ratio = totalTiles > 0 ? revealedCount / totalTiles : 0.0;
    if (ratio <= 0.25) return 8000;
    if (ratio <= 0.50) return 6500;
    if (ratio <= 0.75) return 5000;
    return 3500;
  }

  // Returns guess-opportunity timer duration in ms based on board state after the latest reveal.
  static int _guessOppTimerMs(int revealedCount, int totalTiles) {
    final ratio = totalTiles > 0 ? revealedCount / totalTiles : 0.0;
    if (ratio <= 0.50) return 7000;
    if (ratio <= 0.75) return 5000;
    return 3500;
  }

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
      'revealCycleId': 1,
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
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;

    try {
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(_rooms.doc(roomId));
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);
      final cycleId = room.revealCycleId;
      final shortUid = userId.length > 6 ? userId.substring(0, 6) : userId;

      QaLoggerService.instance.log('REVEAL',
          'REVEAL_TX_BEGIN cycleId=$cycleId pieceIndex=$pieceIndex uid=$shortUid');
      QaLoggerService.instance.log('REVEAL', 'TX_BEGIN name=revealPiece');

      // Duplicate / phase guard: must still be in revealTurn
      if (room.turnPhase != TurnPhase.revealTurn) {
        QaLoggerService.instance.log('REVEAL',
            'REVEAL_TX_ABORT reason=REVEAL_REJECTED_DUPLICATE cycleId=$cycleId phase=${room.turnPhase.name}');
        return;
      }

      // Authorization guard: must be the current turn player
      final currentUser = room.currentTurnUserId;
      if (currentUser != userId) {
        QaLoggerService.instance.log('REVEAL',
            'REVEAL_TX_ABORT reason=REVEAL_REJECTED_UNAUTHORIZED cycleId=$cycleId');
        return;
      }

      // Deadline guard: no late reveals accepted
      final deadline = room.revealDeadlineMs;
      if (deadline != null && now > deadline) {
        QaLoggerService.instance.log('REVEAL',
            'REVEAL_TX_ABORT reason=REVEAL_REJECTED_EXPIRED cycleId=$cycleId deadline=$deadline now=$now');
        return;
      }

      // Piece availability guard: piece must not already be open
      if (!room.availablePieceIndices.contains(pieceIndex)) {
        QaLoggerService.instance.log('REVEAL',
            'REVEAL_TX_ABORT reason=REVEAL_REJECTED_ALREADY_OPEN cycleId=$cycleId pieceIndex=$pieceIndex');
        return;
      }

      final player = room.players[userId];
      if (player == null) return;

      // Compute reveal outcome
      final newHidden = room.availablePieceIndices.where((i) => i != pieceIndex).toList();
      final newScore = player.score + difficulty.placePiecePoints;
      final shouldGrantLetterCard =
          player.letterCards == 0 &&
          !room.letterCardGrantedPlayerIds.contains(userId) &&
          Random().nextDouble() < _letterCardBonusChance;

      // Last tile revealed with no winner — close game immediately
      if (newHidden.isEmpty) {
        final finishUpdates = <String, dynamic>{
          'placedPieces.${pieceIndex.toString()}': userId,
          'availablePieceIndices': newHidden,
          'players.$userId.score': newScore,
          'phase': GamePhase.finished.name,
          'turnPhase': TurnPhase.roundOver.name,
          'guessOpportunityPlayerId': null,
          'guessModePlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'guessModeDeadlineMs': null,
          'lastRevealedByPlayerId': userId,
        };
        if (shouldGrantLetterCard) {
          finishUpdates['players.$userId.letterCards'] = 1;
          finishUpdates['letterCardGrantedPlayerIds'] = FieldValue.arrayUnion([userId]);
        }
        tx.update(_rooms.doc(roomId), finishUpdates);
        QaLoggerService.instance.log('GAME', 'ROUND_OVER_SET_NO_WINNER cycleId=$cycleId');
        QaLoggerService.instance.log('REVEAL',
            'REVEAL_TX_COMMIT cycleId=$cycleId pieceIndex=$pieceIndex');
        QaLoggerService.instance.log('REVEAL',
            'TX_COMMIT name=revealPiece latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
        return;
      }

      // Determine guess opportunity recipient
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

      final totalTiles = room.gridSize * room.gridSize;
      final revealedAfter = totalTiles - newHidden.length;
      final guessOppMs = _guessOppTimerMs(revealedAfter, totalTiles);
      QaLoggerService.instance.log('TURN',
          'GUESS_OPP_TIMER_DYNAMIC ratio=${(revealedAfter / totalTiles).toStringAsFixed(2)} durationMs=$guessOppMs');

      final updates = <String, dynamic>{
        'placedPieces.${pieceIndex.toString()}': userId,
        'availablePieceIndices': newHidden,
        'players.$userId.score': newScore,
        'turnPhase': TurnPhase.guessOpportunity.name,
        'guessOpportunityPlayerId': guessOpportunityPlayerId,
        'guessOpportunityDeadlineMs': now + guessOppMs,
        'lastRevealedByPlayerId': userId,
      };

      if (shouldGrantLetterCard) {
        updates['players.$userId.letterCards'] = 1;
        updates['letterCardGrantedPlayerIds'] = FieldValue.arrayUnion([userId]);
      }

      tx.update(_rooms.doc(roomId), updates);

      QaLoggerService.instance.log('REVEAL',
          'REVEAL_TX_COMMIT cycleId=$cycleId pieceIndex=$pieceIndex');
      QaLoggerService.instance.log('REVEAL',
          'TX_COMMIT name=revealPiece latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
    });
    } catch (e) {
      QaLoggerService.instance.log('REVEAL', 'TX_ERROR name=revealPiece error=$e');
    }
  }

  Future<void> skipPiecePlacement({required String roomId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;
    try {
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(_rooms.doc(roomId));
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);
      QaLoggerService.instance.log('TURN', 'SKIP_TX_BEGIN');
      if (room.phase == GamePhase.finished) {
        QaLoggerService.instance.log('TURN', 'TURN_ADVANCE_SKIPPED_FINISHED method=skipPiecePlacement');
        QaLoggerService.instance.log('TURN', 'SKIP_TX_ABORT reason=game_finished');
        return;
      }
      if (room.turnPhase != TurnPhase.guessOpportunity) {
        QaLoggerService.instance.log('TURN', 'SKIP_TX_ABORT reason=wrong_phase phase=${room.turnPhase.name}');
        return;
      }
      if (room.guessOpportunityDeadlineMs == null) {
        QaLoggerService.instance.log('TURN', 'SKIP_TX_ABORT reason=null_deadline');
        return;
      }
      final skipTotalTiles = room.gridSize * room.gridSize;
      final skipRevealMs = _revealTimerMs(room.placedPieces.length, skipTotalTiles);
      QaLoggerService.instance.log('TURN',
          'REVEAL_TIMER_DYNAMIC ratio=${(room.placedPieces.length / skipTotalTiles).toStringAsFixed(2)} durationMs=$skipRevealMs');
      tx.update(_rooms.doc(roomId), {
        'currentTurnIndex': room.currentTurnIndex + 1,
        'turnPhase': TurnPhase.revealTurn.name,
        'revealDeadlineMs': now + skipRevealMs,
        'guessOpportunityPlayerId': null,
        'guessModePlayerId': null,
        'guessOpportunityDeadlineMs': null,
        'guessModeDeadlineMs': null,
        'revealCycleId': FieldValue.increment(1),
      });
      QaLoggerService.instance.log('TURN', 'SKIP_TX_COMMIT');
      QaLoggerService.instance.log('TURN',
          'TX_COMMIT name=skipPiecePlacement latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
    });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=skipPiecePlacement error=$e');
    }
  }

  /// Called by the player who has the guess opportunity to lock in as the guesser.
  /// Returns true if the transition succeeded.
  Future<bool> enterGuessMode({
    required String roomId,
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;
    bool success = false;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=enterGuessMode reason=missing_room');
          return;
        }
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('TURN', 'TX_BEGIN name=enterGuessMode');

        if (room.turnPhase != TurnPhase.guessOpportunity) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=enterGuessMode reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        if (room.guessOpportunityPlayerId != userId) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=enterGuessMode reason=not_opportunity_player');
          return;
        }
        final deadline = room.guessOpportunityDeadlineMs;
        if (deadline != null && now >= deadline) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=enterGuessMode reason=deadline_expired');
          return;
        }

        tx.update(_rooms.doc(roomId), {
          'turnPhase': TurnPhase.guessMode.name,
          'guessModePlayerId': userId,
          'guessModeDeadlineMs': now + 20000,
        });
        success = true;
        QaLoggerService.instance.log('TURN',
            'TX_COMMIT name=enterGuessMode latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=enterGuessMode error=$e');
      return false;
    }

    return success;
  }

  /// Called by the current-turn player when the reveal timer expires.
  /// Returns true only when the transaction actually writes the next turn.
  /// Returns false on any no-op or error so the caller can schedule a retry.
  Future<bool> advanceTurnOnTimeout({
    required String roomId,
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool committed = false;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) {
          QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_NOOP reason=missing_room');
          return;
        }
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('TURN',
            'REVEAL_TIMEOUT_ADVANCE_ATTEMPT deadline=${room.revealDeadlineMs} actor=$userId');

        if (room.phase == GamePhase.finished) {
          QaLoggerService.instance.log('TURN', 'TURN_ADVANCE_SKIPPED_FINISHED method=advanceTurnOnTimeout');
          QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_NOOP reason=game_finished');
          return;
        }
        if (room.turnPhase != TurnPhase.revealTurn) {
          QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_NOOP reason=wrong_phase');
          return;
        }
        if (room.currentTurnUserId != userId) {
          QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_NOOP reason=unauthorized_current_turn');
          return;
        }
        final deadline = room.revealDeadlineMs;
        if (deadline == null) {
          QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_NOOP reason=deadline_null');
          return;
        }
        if (now < deadline) {
          QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_NOOP reason=deadline_not_expired');
          return;
        }

        final advTotalTiles = room.gridSize * room.gridSize;
        final advRevealMs = _revealTimerMs(room.placedPieces.length, advTotalTiles);
        QaLoggerService.instance.log('TURN',
            'REVEAL_TIMER_DYNAMIC ratio=${(room.placedPieces.length / advTotalTiles).toStringAsFixed(2)} durationMs=$advRevealMs');

        final activePlayerIds = room.turnOrder
            .where((id) => !(room.players[id]?.isEliminated ?? false))
            .toList();
        final newTurnUid = activePlayerIds.isEmpty
            ? userId
            : activePlayerIds[(room.currentTurnIndex + 1) % activePlayerIds.length];

        tx.update(_rooms.doc(roomId), {
          'currentTurnIndex': room.currentTurnIndex + 1,
          'turnPhase': TurnPhase.revealTurn.name,
          'revealDeadlineMs': now + advRevealMs,
          'guessOpportunityPlayerId': null,
          'guessModePlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'guessModeDeadlineMs': null,
          'revealCycleId': FieldValue.increment(1),
        });

        QaLoggerService.instance.log('TURN',
            'REVEAL_TIMEOUT_ADVANCE_COMMIT oldCycle=${room.revealCycleId} newCycle=${room.revealCycleId + 1} newTurnUid=$newTurnUid');
        committed = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'REVEAL_TIMEOUT_ADVANCE_ERROR error=$e');
      return false;
    }

    return committed;
  }

  /// Called when the guess opportunity timer expires without anyone entering guess mode.
  /// Advances the turn and resets to revealTurn.
  Future<void> expireGuessOpportunity({required String roomId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessOpportunity reason=missing_room');
          return;
        }
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('TURN', 'TX_BEGIN name=expireGuessOpportunity');

        if (room.phase == GamePhase.finished) {
          QaLoggerService.instance.log('TURN', 'TURN_ADVANCE_SKIPPED_FINISHED method=expireGuessOpportunity');
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessOpportunity reason=game_finished');
          return;
        }
        if (room.turnPhase != TurnPhase.guessOpportunity) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=expireGuessOpportunity reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        final deadline = room.guessOpportunityDeadlineMs;
        if (deadline == null) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessOpportunity reason=deadline_null');
          return;
        }
        if (now < deadline) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessOpportunity reason=deadline_not_expired');
          return;
        }

        final expOppTotalTiles = room.gridSize * room.gridSize;
        final expOppRevealMs = _revealTimerMs(room.placedPieces.length, expOppTotalTiles);
        QaLoggerService.instance.log('TURN',
            'REVEAL_TIMER_DYNAMIC ratio=${(room.placedPieces.length / expOppTotalTiles).toStringAsFixed(2)} durationMs=$expOppRevealMs');
        tx.update(_rooms.doc(roomId), {
          'currentTurnIndex': room.currentTurnIndex + 1,
          'turnPhase': TurnPhase.revealTurn.name,
          'revealDeadlineMs': now + expOppRevealMs,
          'guessOpportunityPlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'revealCycleId': FieldValue.increment(1),
        });
        QaLoggerService.instance.log('TURN',
            'TX_COMMIT name=expireGuessOpportunity latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=expireGuessOpportunity error=$e');
    }
  }

  /// Called when the guess mode timer expires without a submission.
  /// Deducts a timeout penalty from the guesser's wallet and advances the turn.
  Future<void> expireGuessMode({required String roomId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessMode reason=missing_room');
          return;
        }
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('TURN', 'TX_BEGIN name=expireGuessMode');

        if (room.phase == GamePhase.finished) {
          QaLoggerService.instance.log('TURN', 'TURN_ADVANCE_SKIPPED_FINISHED method=expireGuessMode');
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessMode reason=game_finished');
          return;
        }
        if (room.turnPhase != TurnPhase.guessMode) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=expireGuessMode reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        final deadline = room.guessModeDeadlineMs;
        if (deadline == null) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessMode reason=deadline_null');
          return;
        }
        if (now < deadline) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=expireGuessMode reason=deadline_not_expired');
          return;
        }

        final guesserUid = room.guessModePlayerId;
        if (guesserUid != null) {
          final walletDoc = await tx.get(_walletRef(guesserUid));
          final wallet = walletDoc.exists
              ? UserEconomyModel.fromFirestore(
                  guesserUid, walletDoc.data() as Map<String, dynamic>)
              : null;
          final before = wallet?.coins ?? 0;
          final deduct = before > 0
              ? EconomyConfig.guessTimeoutLivePenalty.clamp(0, before)
              : 0;
          final after = before - deduct;

          if (deduct > 0) {
            tx.set(_walletRef(guesserUid), {'coins': after}, SetOptions(merge: true));
            final txId = _uuid.v4();
            tx.set(_txRef(guesserUid, txId), EconomyTransactionModel(
              id: txId,
              type: TransactionType.guessTimeoutPenalty,
              delta: -deduct,
              balanceAfter: after,
              roomId: roomId,
              createdAt: DateTime.now().toUtc(),
            ).toFirestore());
            QaLoggerService.instance.log('ECONOMY',
                'GUESS_TIMEOUT_PENALTY_APPLIED amount=$deduct before=$before after=$after');
          } else {
            QaLoggerService.instance.log('ECONOMY',
                'GUESS_TIMEOUT_PENALTY_SKIPPED reason=zero_balance');
          }
        }

        final expGmTotalTiles = room.gridSize * room.gridSize;
        final expGmRevealMs = _revealTimerMs(room.placedPieces.length, expGmTotalTiles);
        QaLoggerService.instance.log('TURN',
            'REVEAL_TIMER_DYNAMIC ratio=${(room.placedPieces.length / expGmTotalTiles).toStringAsFixed(2)} durationMs=$expGmRevealMs');
        tx.update(_rooms.doc(roomId), {
          'currentTurnIndex': room.currentTurnIndex + 1,
          'turnPhase': TurnPhase.revealTurn.name,
          'revealDeadlineMs': now + expGmRevealMs,
          'guessModePlayerId': null,
          'guessOpportunityPlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'guessModeDeadlineMs': null,
          'revealCycleId': FieldValue.increment(1),
        });
        QaLoggerService.instance.log('TURN',
            'TX_COMMIT name=expireGuessMode latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=expireGuessMode error=$e');
    }
  }

  Future<bool> submitAnswer({
    required String roomId,
    required String userId,
    required String guess,
    required GameImageModel image,
    required Difficulty difficulty,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = nowMs;
    bool isCorrect = false;
    bool needsEliminationCheck = false;

    try {
    await _firestore.runTransaction((tx) async {
      final roomDoc = await tx.get(_rooms.doc(roomId));
      if (!roomDoc.exists) {
        QaLoggerService.instance.log('GUESS', 'TX_ABORT name=submitAnswer reason=missing_room');
        return;
      }
      final room = RoomModel.fromFirestore(roomDoc);

      QaLoggerService.instance.log('GUESS', 'TX_BEGIN name=submitAnswer');

      // Authorization guard: only the designated guesser in guessMode may submit
      if (room.turnPhase != TurnPhase.guessMode) {
        QaLoggerService.instance.log('GUESS', 'GUESS_SUBMIT_DUPLICATE_REJECTED phase=${room.turnPhase.name}');
        QaLoggerService.instance.log('GUESS', 'TX_ABORT name=submitAnswer reason=wrong_phase phase=${room.turnPhase.name}');
        return;
      }
      if (room.guessModePlayerId != userId) {
        QaLoggerService.instance.log('GUESS', 'GUESS_SUBMIT_REJECTED_UNAUTHORIZED');
        QaLoggerService.instance.log('GUESS', 'TX_ABORT name=submitAnswer reason=unauthorized');
        return;
      }

      isCorrect = image.isCorrectAnswer(guess);

      if (isCorrect) {
        tx.update(_rooms.doc(roomId), {
          'phase': GamePhase.finished.name,
          'winnerId': userId,
          'players.$userId.score': FieldValue.increment(difficulty.winReward),
          'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': true},
          'guessCount': FieldValue.increment(1),
          'turnPhase': TurnPhase.roundOver.name,
          'guessModePlayerId': null,
          'guessOpportunityPlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'guessModeDeadlineMs': null,
        });
        QaLoggerService.instance.log('GUESS',
            'TX_COMMIT name=submitAnswer result=correct latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
        return;
      }

      // Wrong guess — deduct live penalty from wallet within same transaction
      final walletDoc = await tx.get(_walletRef(userId));
      final wallet = walletDoc.exists
          ? UserEconomyModel.fromFirestore(
              userId, walletDoc.data() as Map<String, dynamic>)
          : null;
      final before = wallet?.coins ?? 0;
      final deduct = before > 0
          ? EconomyConfig.wrongGuessLivePenalty.clamp(0, before)
          : 0;
      final after = before - deduct;

      if (deduct > 0) {
        tx.set(_walletRef(userId), {'coins': after}, SetOptions(merge: true));
        final txId = _uuid.v4();
        tx.set(_txRef(userId, txId), EconomyTransactionModel(
          id: txId,
          type: TransactionType.wrongGuessPenalty,
          delta: -deduct,
          balanceAfter: after,
          roomId: roomId,
          createdAt: DateTime.now().toUtc(),
        ).toFirestore());
        QaLoggerService.instance.log('ECONOMY',
            'WRONG_GUESS_PENALTY_APPLIED amount=$deduct before=$before after=$after');
      } else {
        QaLoggerService.instance.log('ECONOMY',
            'WRONG_GUESS_PENALTY_SKIPPED reason=zero_balance');
      }

      final currentScore = room.players[userId]?.score ?? 0;
      final newScore = currentScore - difficulty.wrongGuessPenalty;
      final nextTurnIndex = room.currentTurnIndex + 1;
      final currentWrongCount = room.wrongGuessCounts[userId] ?? 0;

      final _wgTotalTiles = room.gridSize * room.gridSize;
      final _wgRevealMs = _revealTimerMs(room.placedPieces.length, _wgTotalTiles);
      QaLoggerService.instance.log('TURN',
          'REVEAL_TIMER_DYNAMIC ratio=${(room.placedPieces.length / _wgTotalTiles).toStringAsFixed(2)} durationMs=$_wgRevealMs');

      final updates = <String, dynamic>{
        'currentTurnIndex': nextTurnIndex,
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
        'guessCount': FieldValue.increment(1),
        'turnPhase': TurnPhase.revealTurn.name,
        'revealDeadlineMs': nowMs + _wgRevealMs,
        'guessModePlayerId': null,
        'guessOpportunityPlayerId': null,
        'guessOpportunityDeadlineMs': null,
        'guessModeDeadlineMs': null,
        'wrongGuessCounts.$userId': currentWrongCount + 1,
        'revealCycleId': FieldValue.increment(1),
      };

      if (newScore <= 0) {
        updates['players.$userId.score'] = 0;
        updates['players.$userId.isEliminated'] = true;
        needsEliminationCheck = true;
      } else {
        updates['players.$userId.score'] = newScore;
      }

      tx.update(_rooms.doc(roomId), updates);
      QaLoggerService.instance.log('GUESS',
          'TX_COMMIT name=submitAnswer result=wrong latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
    });
    } catch (e) {
      QaLoggerService.instance.log('GUESS', 'TX_ERROR name=submitAnswer error=$e');
    }

    if (!isCorrect && needsEliminationCheck) {
      await _checkLastPlayerStanding(roomId);
    }
    return isCorrect;
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
