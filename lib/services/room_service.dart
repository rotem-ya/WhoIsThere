import 'dart:async';
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

/// Picks a tile index using a checkerboard-first strategy.
/// Prefers tiles that have no revealed neighbour (up/down/left/right).
/// Falls back to any available tile only when every candidate is adjacent.
int _pickCheckerboardTile(
  List<int> available,
  Set<int> revealed,
  int gridSize,
  Random rng,
) {
  bool _hasRevealedNeighbour(int idx) {
    final r = idx ~/ gridSize;
    final c = idx % gridSize;
    if (r > 0 && revealed.contains(idx - gridSize)) return true;
    if (r < gridSize - 1 && revealed.contains(idx + gridSize)) return true;
    if (c > 0 && revealed.contains(idx - 1)) return true;
    if (c < gridSize - 1 && revealed.contains(idx + 1)) return true;
    return false;
  }

  final isolated = available.where((i) => !_hasRevealedNeighbour(i)).toList();
  final pool = isolated.isNotEmpty ? isolated : available;
  return pool[rng.nextInt(pool.length)];
}

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _rooms => _firestore.collection('rooms');

  static const _uuid = Uuid();

  DocumentReference _walletRef(String uid) =>
      _firestore.doc('users/$uid/economy/wallet');

  DocumentReference _txRef(String uid, String txId) =>
      _firestore.doc('users/$uid/economy_transactions/$txId');

  static const double _letterCardBonusChance = 0.12;

  // Returns reveal timer duration in ms — flat 10 seconds regardless of board state.
  static int _revealTimerMs(int revealedCount, int totalTiles) => 10000;

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
    int entryFee = EconomyConfig.gameEntryFee,
  }) async {
    final code = RoomCodeGenerator.generate();
    final docRef = _rooms.doc();

    // Read the host's selected card skin, total points and discovered count
    final userSnap = await _firestore.doc('users/$hostId').get();
    final cardSkinId = (userSnap.data()?['selectedCardSkin'] as String?) ?? 'default';
    final hostTotalPoints = (userSnap.data()?['totalPoints'] as int?) ?? 0;
    final hostDiscoveredCount =
        (userSnap.data()?['discoveredImageIds'] as List?)?.length ?? 0;

    final host = PlayerModel(
      id: hostId,
      name: hostName,
      photoUrl: hostPhotoUrl,
      score: 0,
      totalPoints: hostTotalPoints,
      discoveredCount: hostDiscoveredCount,
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
      entryFee: entryFee,
      cardSkinId: cardSkinId,
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

    final joiningUserSnap = await _firestore.doc('users/$userId').get();
    final joiningTotalPoints = (joiningUserSnap.data()?['totalPoints'] as int?) ?? 0;
    final joiningDiscoveredCount =
        (joiningUserSnap.data()?['discoveredImageIds'] as List?)?.length ?? 0;

    final newPlayer = PlayerModel(
      id: userId,
      name: userName,
      photoUrl: userPhotoUrl,
      score: 0,
      totalPoints: joiningTotalPoints,
      discoveredCount: joiningDiscoveredCount,
    );

    await doc.reference.update({
      'players.$userId': newPlayer.toMap(),
    });

    return RoomModel.fromFirestore(await doc.reference.get());
  }

  /// Adds a single bot player to an existing waiting room.
  Future<void> addBotToRoom(String roomId, int botIndex) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return;
    final room = RoomModel.fromFirestore(doc);
    if (room.phase != GamePhase.waiting) return;

    final virtualId = 'virtual_${botIndex}_$roomId';
    if (room.players.containsKey(virtualId)) return;

    final botPlayer = PlayerModel(
      id: virtualId,
      name: 'שחקן $botIndex',
      score: 0,
      isBot: true,
    );
    await _rooms.doc(roomId).update({
      'players.$virtualId': botPlayer.toMap(),
    });
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

  void _recordDiscoveredForAll(Map<String, PlayerModel> players, String imageId) {
    for (final entry in players.entries) {
      if (!entry.value.isBot) {
        _firestore.doc('users/${entry.key}').update({
          'discoveredImageIds': FieldValue.arrayUnion([imageId]),
        }).ignore();
      }
    }
  }

  Future<void> _startGame(
    String roomId,
    RoomModel room,
    Difficulty difficulty,
  ) async {
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
      'revealDeadlineMs': nowMs + EconomyConfig.autoRevealIntervalMs,
      'guessOpportunityPlayerId': null,
      'guessModePlayerId': null,
      'lastRevealedByPlayerId': null,
      'guessOpportunityDeadlineMs': null,
      'guessModeDeadlineMs': null,
      'wrongGuessCounts': {},
      'guessClaimCounts': {},
      'revealCycleId': 1,
      'revealCount': 0,
      'blockedGuessers': {},
      // Bots have no real client to call payMyEntryFee — seed their share now.
      'potTotal': room.players.values.where((p) => p.isBot).length * room.entryFee,
      'entryFeePaidPlayerIds': [],
    });
  }

  Future<void> _collectEntryFees(
    String roomId,
    Map<String, PlayerModel> players,
    int entryFee,
  ) async {
    final humanIds = players.entries
        .where((e) => !e.value.isBot)
        .map((e) => e.key)
        .toList();

    var potCollected = 0;
    for (final uid in humanIds) {
      try {
        await _firestore.runTransaction((tx) async {
          final walletDoc = await tx.get(_walletRef(uid));
          final wallet = walletDoc.exists
              ? UserEconomyModel.fromFirestore(
                  uid, walletDoc.data() as Map<String, dynamic>)
              : null;
          final before = wallet?.coins ?? 0;
          // Always charge — balance can go negative (debt)
          final after = before - entryFee;
          tx.set(_walletRef(uid), {'coins': after}, SetOptions(merge: true));
          final txId = _uuid.v4();
          tx.set(_txRef(uid, txId), EconomyTransactionModel(
            id: txId,
            type: TransactionType.roomEntryFee,
            delta: -entryFee,
            balanceAfter: after,
            roomId: roomId,
            createdAt: DateTime.now().toUtc(),
            meta: {'entryFee': entryFee},
          ).toFirestore());
          potCollected += entryFee;
        });
      } catch (e) {
        QaLoggerService.instance.log('ECONOMY',
            'ENTRY_FEE_COLLECT_ERROR uid=${uid.substring(0, uid.length.clamp(0, 6))} error=$e');
      }
    }

    if (potCollected > 0) {
      await _rooms.doc(roomId).update({
        'potTotal': FieldValue.increment(potCollected),
      });
      QaLoggerService.instance.log('ECONOMY',
          'ENTRY_FEES_COLLECTED total=$potCollected players=${humanIds.length}');
    }
  }

  /// Called by each player's own client when the game starts.
  /// Uses an idempotency list (entryFeePaidPlayerIds) so double-payment is impossible.
  Future<void> payMyEntryFee({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final roomDoc = await tx.get(_rooms.doc(roomId));
        if (!roomDoc.exists) return;
        final room = RoomModel.fromFirestore(roomDoc);

        // Idempotency guard
        if (room.entryFeePaidPlayerIds.contains(userId)) return;
        if (room.entryFee <= 0) return;
        if (room.phase != GamePhase.playing) return;

        final walletDoc = await tx.get(_walletRef(userId));
        final wallet = walletDoc.exists
            ? UserEconomyModel.fromFirestore(userId, walletDoc.data() as Map<String, dynamic>)
            : null;
        final before = wallet?.coins ?? 0;
        final after = before - room.entryFee; // Allow debt

        tx.set(_walletRef(userId), {'coins': after}, SetOptions(merge: true));

        final txId = _uuid.v4();
        tx.set(_txRef(userId, txId), EconomyTransactionModel(
          id: txId,
          type: TransactionType.roomEntryFee,
          delta: -room.entryFee,
          balanceAfter: after,
          roomId: roomId,
          createdAt: DateTime.now().toUtc(),
          meta: {'entryFee': room.entryFee},
        ).toFirestore());

        tx.update(_rooms.doc(roomId), {
          'potTotal': FieldValue.increment(room.entryFee),
          'entryFeePaidPlayerIds': FieldValue.arrayUnion([userId]),
        });
      });
      QaLoggerService.instance.log('ECONOMY', 'ENTRY_FEE_PAID userId=${userId.substring(0, userId.length.clamp(0, 6))}');
    } catch (e) {
      QaLoggerService.instance.log('ECONOMY', 'ENTRY_FEE_PAY_ERROR error=$e');
    }
  }

  Future<void> distributePot(String roomId, String winnerId) async {
    try {
      final doc = await _rooms.doc(roomId).get();
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);
      final pot = room.potTotal;
      if (pot <= 0 || winnerId.startsWith('virtual_')) return;

      await _firestore.runTransaction((tx) async {
        final walletDoc = await tx.get(_walletRef(winnerId));
        final wallet = walletDoc.exists
            ? UserEconomyModel.fromFirestore(
                winnerId, walletDoc.data() as Map<String, dynamic>)
            : null;
        final before = wallet?.coins ?? 0;
        final after = before + pot;
        tx.set(_walletRef(winnerId), {'coins': after}, SetOptions(merge: true));
        final txId = _uuid.v4();
        tx.set(_txRef(winnerId, txId), EconomyTransactionModel(
          id: txId,
          type: TransactionType.potWin,
          delta: pot,
          balanceAfter: after,
          roomId: roomId,
          createdAt: DateTime.now().toUtc(),
          meta: {'potAmount': pot},
        ).toFirestore());
      });
      QaLoggerService.instance.log('ECONOMY',
          'POT_DISTRIBUTED amount=$pot winner=${winnerId.substring(0, winnerId.length.clamp(0, 6))}');
    } catch (e) {
      QaLoggerService.instance.log('ECONOMY', 'POT_DISTRIBUTE_ERROR error=$e');
    }
  }

  Future<void> refundPot(String roomId) async {
    try {
      final doc = await _rooms.doc(roomId).get();
      if (!doc.exists) return;
      final room = RoomModel.fromFirestore(doc);
      final pot = room.potTotal;
      if (pot <= 0) return;

      final humanIds = room.players.entries
          .where((e) => !e.value.isBot)
          .map((e) => e.key)
          .toList();
      if (humanIds.isEmpty) return;

      final share = pot ~/ humanIds.length;
      if (share <= 0) return;

      for (final uid in humanIds) {
        try {
          await _firestore.runTransaction((tx) async {
            final walletDoc = await tx.get(_walletRef(uid));
            final wallet = walletDoc.exists
                ? UserEconomyModel.fromFirestore(
                    uid, walletDoc.data() as Map<String, dynamic>)
                : null;
            final before = wallet?.coins ?? 0;
            final after = before + share;
            tx.set(_walletRef(uid), {'coins': after}, SetOptions(merge: true));
            final txId = _uuid.v4();
            tx.set(_txRef(uid, txId), EconomyTransactionModel(
              id: txId,
              type: TransactionType.potRefund,
              delta: share,
              balanceAfter: after,
              roomId: roomId,
              createdAt: DateTime.now().toUtc(),
              meta: {'refundShare': share, 'totalPot': pot},
            ).toFirestore());
          });
        } catch (_) {}
      }
      QaLoggerService.instance.log('ECONOMY',
          'POT_REFUNDED total=$pot players=${humanIds.length} shareEach=$share');
    } catch (e) {
      QaLoggerService.instance.log('ECONOMY', 'POT_REFUND_ERROR error=$e');
    }
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
      if (e is FirebaseException && e.code == 'unavailable') rethrow;
    }
  }

  /// Auto-reveals a random tile on behalf of the system (no player auth required).
  /// This is called by the guardian client when the revealDeadline expires.
  /// Returns true only when a tile was actually revealed.
  Future<bool> autoRevealPiece({
    required String roomId,
    required String actorUid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;
    bool committed = false;
    bool noWinner = false;
    List<String>? playerIdsForRefund;
    Map<String, PlayerModel>? noWinnerPlayers;
    String? noWinnerImageId;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) return;
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('REVEAL', 'TX_BEGIN name=autoRevealPiece');

        if (room.phase == GamePhase.finished) {
          QaLoggerService.instance.log('REVEAL', 'AUTO_REVEAL_ABORT reason=game_finished');
          return;
        }
        if (room.turnPhase != TurnPhase.revealTurn) {
          QaLoggerService.instance.log('REVEAL',
              'AUTO_REVEAL_ABORT reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        final deadline = room.revealDeadlineMs;
        if (deadline == null || now < deadline) {
          QaLoggerService.instance.log('REVEAL', 'AUTO_REVEAL_ABORT reason=deadline_not_expired');
          return;
        }
        if (room.availablePieceIndices.isEmpty && room.pendingRevealTileIndex == null) {
          QaLoggerService.instance.log('REVEAL', 'AUTO_REVEAL_ABORT reason=no_tiles_left');
          return;
        }

        // ── Phase 2: pending tile exists → reveal it ─────────────────────────
        if (room.pendingRevealTileIndex != null) {
          final pieceIndex = room.pendingRevealTileIndex!;
          final newHidden = room.availablePieceIndices
              .where((i) => i != pieceIndex)
              .toList();
          final newRevealCount = room.revealCount + 1;

          if (newHidden.isEmpty) {
            tx.update(_rooms.doc(roomId), {
              'placedPieces.${pieceIndex.toString()}': 'system',
              'availablePieceIndices': newHidden,
              'pendingRevealTileIndex': FieldValue.delete(),
              'phase': GamePhase.finished.name,
              'turnPhase': TurnPhase.roundOver.name,
              'guessOpportunityPlayerId': null,
              'guessModePlayerId': null,
              'guessOpportunityDeadlineMs': null,
              'guessModeDeadlineMs': null,
              'lastRevealedByPlayerId': null,
              'revealCount': newRevealCount,
              'revealCycleId': FieldValue.increment(1),
            });
            QaLoggerService.instance.log('GAME', 'AUTO_REVEAL_LAST_TILE_NO_WINNER');
            committed = true;
            noWinner = true;
            playerIdsForRefund = room.players.keys.toList();
            noWinnerPlayers = room.players;
            noWinnerImageId = room.selectedImageId;
            return;
          }

          final totalTiles = room.gridSize * room.gridSize;
          final revealedAfter = totalTiles - newHidden.length;
          final guessOppMs = _guessOppTimerMs(revealedAfter, totalTiles);

          tx.update(_rooms.doc(roomId), {
            'placedPieces.${pieceIndex.toString()}': 'system',
            'availablePieceIndices': newHidden,
            'pendingRevealTileIndex': FieldValue.delete(),
            'turnPhase': TurnPhase.guessOpportunity.name,
            'guessOpportunityPlayerId': null,
            'guessOpportunityDeadlineMs': now + guessOppMs,
            'lastRevealedByPlayerId': null,
            'revealCount': newRevealCount,
            'revealCycleId': FieldValue.increment(1),
          });

          QaLoggerService.instance.log('REVEAL',
              'AUTO_REVEAL_COMMIT pieceIndex=$pieceIndex revealCount=$newRevealCount guessOppMs=$guessOppMs');
          QaLoggerService.instance.log('REVEAL',
              'TX_COMMIT name=autoRevealPiece latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
          committed = true;
          return;
        }

        // ── Phase 1: no pending tile → pick one and start 5-second countdown ─
        final rng = Random();
        final revealedSet = room.placedPieces.keys.toSet();
        final pieceIndex = _pickCheckerboardTile(
          room.availablePieceIndices,
          revealedSet,
          room.gridSize,
          rng,
        );

        tx.update(_rooms.doc(roomId), {
          'pendingRevealTileIndex': pieceIndex,
          'revealDeadlineMs': now + 10000,
          'revealCycleId': FieldValue.increment(1),
        });
        QaLoggerService.instance.log('REVEAL',
            'AUTO_REVEAL_PENDING pieceIndex=$pieceIndex countdownMs=10000');
        committed = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('REVEAL', 'TX_ERROR name=autoRevealPiece error=$e');
      if (e is FirebaseException && e.code == 'unavailable') rethrow;
    }

    if (noWinner && playerIdsForRefund != null) {
      unawaited(refundPot(roomId));
      if (noWinnerPlayers != null && noWinnerImageId != null && noWinnerImageId!.isNotEmpty) {
        _recordDiscoveredForAll(noWinnerPlayers!, noWinnerImageId!);
      }
    }

    return committed;
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
      tx.update(_rooms.doc(roomId), {
        'turnPhase': TurnPhase.revealTurn.name,
        'revealDeadlineMs': now + EconomyConfig.autoRevealIntervalMs,
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
        // Race mechanic: slot must be unclaimed (null = open to all)
        if (room.guessOpportunityPlayerId != null) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=enterGuessMode reason=already_claimed player=${room.guessOpportunityPlayerId}');
          return;
        }
        if (room.isBlockedFromGuessing(userId)) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=enterGuessMode reason=player_blocked uid=${userId.substring(0, userId.length.clamp(0, 6))} blockedUntil=${room.blockedGuessers[userId]}');
          return;
        }
        final deadline = room.guessOpportunityDeadlineMs;
        if (deadline != null && now >= deadline) {
          QaLoggerService.instance.log('TURN', 'TX_ABORT name=enterGuessMode reason=deadline_expired');
          return;
        }

        // Bots (virtual_*) have no wallet — skip fee logic entirely to avoid
        // permission-denied on the wallet document read.
        final isBot = userId.startsWith('virtual_');
        final claimCount = room.guessClaimCounts[userId] ?? 0;
        int actualCost = 0;

        if (!isBot) {
          final claimCost = EconomyConfig.baseGuessClaimCost +
              (claimCount * EconomyConfig.guessClaimCostIncrement);
          final walletDoc = await tx.get(_walletRef(userId));
          final wallet = walletDoc.exists
              ? UserEconomyModel.fromFirestore(
                  userId, walletDoc.data() as Map<String, dynamic>)
              : null;
          final coinsBefore = wallet?.coins ?? 0;
          actualCost = claimCost;
          final coinsAfter = coinsBefore - actualCost;

          if (actualCost > 0) {
            tx.set(_walletRef(userId), {'coins': coinsAfter}, SetOptions(merge: true));
            final txId = _uuid.v4();
            tx.set(
              _txRef(userId, txId),
              EconomyTransactionModel(
                id: txId,
                type: TransactionType.guessClaimFee,
                delta: -actualCost,
                balanceAfter: coinsAfter,
                roomId: roomId,
                createdAt: DateTime.now().toUtc(),
                meta: {'claimNumber': claimCount + 1, 'claimCost': actualCost},
              ).toFirestore(),
            );
          }
        }

        // Atomically claim the guess slot, enter guessMode, track claim count, add to pot
        tx.update(_rooms.doc(roomId), {
          'turnPhase': TurnPhase.guessMode.name,
          'guessOpportunityPlayerId': userId,
          'guessModePlayerId': userId,
          'guessModeDeadlineMs': now + 20000,
          'guessClaimCounts.$userId': claimCount + 1,
          if (actualCost > 0) 'potTotal': FieldValue.increment(actualCost),
        });
        success = true;
        QaLoggerService.instance.log('TURN',
            'TX_COMMIT name=enterGuessMode claimCost=$actualCost claimNumber=${claimCount + 1} latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=enterGuessMode error=$e');
      if (e is FirebaseException && e.code == 'unavailable') rethrow;
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
    bool guardianAllowed = false,
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
        final currentOwner = room.currentTurnUserId;
        final ownerIsVirtual = currentOwner != null && currentOwner.startsWith('virtual_');
        final isGuardian = guardianAllowed && !ownerIsVirtual &&
            currentOwner != null && currentOwner != userId;
        if (currentOwner != userId && !ownerIsVirtual && !isGuardian) {
          QaLoggerService.instance.log('TURN',
              'REVEAL_TIMEOUT_ADVANCE_NOOP reason=unauthorized_current_turn owner=${currentOwner ?? 'null'} actor=$userId');
          return;
        }
        if (ownerIsVirtual) {
          QaLoggerService.instance.log('TURN',
              'REVEAL_TIMEOUT_VIRTUAL_GUARDIAN_ALLOWED owner=$currentOwner actor=$userId');
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
        if (isGuardian) {
          final guardianOverdue = now - deadline;
          if (guardianOverdue < 90000) {
            QaLoggerService.instance.log('TURN',
                'REVEAL_TIMEOUT_ADVANCE_NOOP reason=guardian_threshold_not_met overdueMs=$guardianOverdue');
            return;
          }
          QaLoggerService.instance.log('TURN',
              'GUARDIAN_TIMEOUT_ALLOWED owner=$currentOwner actor=$userId overdueMs=$guardianOverdue');
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
  /// Returns true only when the transaction actually commits and advances state.
  Future<bool> expireGuessOpportunity({required String roomId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;
    bool committed = false;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) {
          QaLoggerService.instance.log('TURN',
              'GUESS_OPP_TIMEOUT_ADVANCE_NOOP reason=missing_room');
          return;
        }
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('TURN',
            'TX_BEGIN name=expireGuessOpportunity');
        QaLoggerService.instance.log('TURN',
            'GUESS_OPP_TIMEOUT_ADVANCE_ATTEMPT deadline=${room.guessOpportunityDeadlineMs} actor=${room.guessOpportunityPlayerId ?? 'none'}');

        if (room.phase == GamePhase.finished) {
          QaLoggerService.instance.log('TURN', 'TURN_ADVANCE_SKIPPED_FINISHED method=expireGuessOpportunity');
          QaLoggerService.instance.log('TURN',
              'GUESS_OPP_TIMEOUT_ADVANCE_NOOP reason=game_finished');
          return;
        }
        if (room.turnPhase != TurnPhase.guessOpportunity) {
          QaLoggerService.instance.log('TURN',
              'GUESS_OPP_TIMEOUT_ADVANCE_NOOP reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        final deadline = room.guessOpportunityDeadlineMs;
        if (deadline == null) {
          QaLoggerService.instance.log('TURN',
              'GUESS_OPP_TIMEOUT_ADVANCE_NOOP reason=deadline_null');
          return;
        }
        if (now < deadline) {
          QaLoggerService.instance.log('TURN',
              'GUESS_OPP_TIMEOUT_ADVANCE_NOOP reason=deadline_not_expired');
          return;
        }

        tx.update(_rooms.doc(roomId), {
          'currentTurnIndex': room.currentTurnIndex + 1,
          'turnPhase': TurnPhase.revealTurn.name,
          'revealDeadlineMs': now + EconomyConfig.autoRevealIntervalMs,
          'guessOpportunityPlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'revealCycleId': FieldValue.increment(1),
        });
        QaLoggerService.instance.log('TURN',
            'GUESS_OPP_TIMEOUT_ADVANCE_COMMIT oldCycle=${room.revealCycleId} newCycle=${room.revealCycleId + 1} newTurnIndex=${room.currentTurnIndex + 1}');
        QaLoggerService.instance.log('TURN',
            'TX_COMMIT name=expireGuessOpportunity latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
        committed = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'GUESS_OPP_TIMEOUT_ADVANCE_ERROR error=$e');
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=expireGuessOpportunity error=$e');
      return false;
    }

    return committed;
  }

  /// Called when the guess mode timer expires without a submission.
  /// Deducts a timeout penalty from the guesser's wallet and advances the turn.
  /// Returns true only when the transaction actually commits and advances state.
  Future<bool> expireGuessMode({required String roomId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final txStartMs = now;
    bool committed = false;

    try {
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(_rooms.doc(roomId));
        if (!doc.exists) {
          QaLoggerService.instance.log('TURN',
              'GUESS_MODE_TIMEOUT_ADVANCE_NOOP reason=missing_room');
          return;
        }
        final room = RoomModel.fromFirestore(doc);

        QaLoggerService.instance.log('TURN', 'TX_BEGIN name=expireGuessMode');
        QaLoggerService.instance.log('TURN',
            'GUESS_MODE_TIMEOUT_ADVANCE_ATTEMPT deadline=${room.guessModeDeadlineMs} actor=${room.guessModePlayerId ?? 'none'}');

        if (room.phase == GamePhase.finished) {
          QaLoggerService.instance.log('TURN', 'TURN_ADVANCE_SKIPPED_FINISHED method=expireGuessMode');
          QaLoggerService.instance.log('TURN',
              'GUESS_MODE_TIMEOUT_ADVANCE_NOOP reason=game_finished');
          return;
        }
        if (room.turnPhase != TurnPhase.guessMode) {
          QaLoggerService.instance.log('TURN',
              'GUESS_MODE_TIMEOUT_ADVANCE_NOOP reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        final deadline = room.guessModeDeadlineMs;
        if (deadline == null) {
          QaLoggerService.instance.log('TURN',
              'GUESS_MODE_TIMEOUT_ADVANCE_NOOP reason=deadline_null');
          return;
        }
        if (now < deadline) {
          QaLoggerService.instance.log('TURN',
              'GUESS_MODE_TIMEOUT_ADVANCE_NOOP reason=deadline_not_expired');
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

        final updates = <String, dynamic>{
          'turnPhase': TurnPhase.revealTurn.name,
          'revealDeadlineMs': now + EconomyConfig.autoRevealIntervalMs,
          'guessModePlayerId': null,
          'guessOpportunityPlayerId': null,
          'guessOpportunityDeadlineMs': null,
          'guessModeDeadlineMs': null,
          'revealCycleId': FieldValue.increment(1),
        };
        if (guesserUid != null) {
          updates['blockedGuessers.$guesserUid'] = room.revealCount + 2;
        }
        tx.update(_rooms.doc(roomId), updates);
        QaLoggerService.instance.log('TURN',
            'GUESS_MODE_TIMEOUT_ADVANCE_COMMIT oldCycle=${room.revealCycleId} newCycle=${room.revealCycleId + 1} blockedUid=$guesserUid');
        QaLoggerService.instance.log('TURN',
            'TX_COMMIT name=expireGuessMode latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
        committed = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('TURN', 'GUESS_MODE_TIMEOUT_ADVANCE_ERROR error=$e');
      QaLoggerService.instance.log('TURN', 'TX_ERROR name=expireGuessMode error=$e');
      return false;
    }

    return committed;
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

      // Wrong guess — dynamic penalty: 2 coins for 1st wrong, +2 for each subsequent (goes to pot)
      final walletDoc = await tx.get(_walletRef(userId));
      final wallet = walletDoc.exists
          ? UserEconomyModel.fromFirestore(
              userId, walletDoc.data() as Map<String, dynamic>)
          : null;
      final before = wallet?.coins ?? 0;
      final currentWrongCount = room.wrongGuessCounts[userId] ?? 0;

      final wrongPenalty = EconomyConfig.baseWrongGuessPenalty +
          (currentWrongCount * EconomyConfig.wrongGuessPenaltyIncrement);
      // Always apply full penalty — balance can go negative (debt)
      final actualPenalty = wrongPenalty;
      final after = before - actualPenalty;

      if (actualPenalty > 0) {
        tx.set(_walletRef(userId), {'coins': after}, SetOptions(merge: true));
        final txId = _uuid.v4();
        tx.set(_txRef(userId, txId), EconomyTransactionModel(
          id: txId,
          type: TransactionType.wrongGuessPenalty,
          delta: -actualPenalty,
          balanceAfter: after,
          roomId: roomId,
          createdAt: DateTime.now().toUtc(),
          meta: {'wrongGuessNumber': currentWrongCount + 1, 'penalty': actualPenalty},
        ).toFirestore());
        QaLoggerService.instance.log('ECONOMY',
            'WRONG_GUESS_PENALTY wrongNumber=${currentWrongCount + 1} penalty=$actualPenalty before=$before after=$after');
      } else {
        QaLoggerService.instance.log('ECONOMY', 'WRONG_GUESS_PENALTY_SKIPPED reason=zero_balance');
      }

      final currentScore = room.players[userId]?.score ?? 0;
      final newScore = currentScore - difficulty.wrongGuessPenalty;
      final nextTurnIndex = room.currentTurnIndex + 1;

      final updates = <String, dynamic>{
        'currentTurnIndex': nextTurnIndex,
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
        'guessCount': FieldValue.increment(1),
        'turnPhase': TurnPhase.revealTurn.name,
        'revealDeadlineMs': nowMs + EconomyConfig.autoRevealIntervalMs,
        'guessModePlayerId': null,
        'guessOpportunityPlayerId': null,
        'guessOpportunityDeadlineMs': null,
        'guessModeDeadlineMs': null,
        'wrongGuessCounts.$userId': currentWrongCount + 1,
        'revealCycleId': FieldValue.increment(1),
        'blockedGuessers.$userId': room.revealCount + EconomyConfig.wrongGuessBlockTurns,
      };

      // Wrong-guess penalty goes entirely to pot
      if (actualPenalty > 0) {
        updates['potTotal'] = FieldValue.increment(actualPenalty);
        QaLoggerService.instance.log('ECONOMY',
            'POT_PENALTY_ADDED amount=$actualPenalty newPot=${room.potTotal + actualPenalty}');
      }

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
      if (e is FirebaseException && e.code == 'unavailable') rethrow;
    }

    if (isCorrect) {
      unawaited(distributePot(roomId, userId));
      // Record discovered image for all players only when game ends with a correct answer
      final roomSnap = await _rooms.doc(roomId).get();
      if (roomSnap.exists) {
        final endRoom = RoomModel.fromFirestore(roomSnap);
        if (endRoom.selectedImageId != null && endRoom.selectedImageId!.isNotEmpty) {
          _recordDiscoveredForAll(endRoom.players, endRoom.selectedImageId!);
        }
      }
    } else if (needsEliminationCheck) {
      await _checkLastPlayerStanding(roomId);
    }
    return isCorrect;
  }

  Future<void> endGameNoWinner(String roomId) async {
    await _rooms.doc(roomId).update({
      'phase': GamePhase.finished.name,
    });
    unawaited(refundPot(roomId));
  }

  /// Atomically consumes one stun card from actorUid's inventory and
  /// blocks targetUid from guessing for [stunCardBlockTurns] reveal cycles.
  Future<bool> applyStunCard({
    required String roomId,
    required String actorUid,
    required String targetUid,
  }) async {
    bool success = false;
    try {
      await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(_firestore.doc('users/$actorUid'));
        final count = (userSnap.data()?['stunCardCount'] as int?) ?? 0;
        if (count <= 0) return;

        final roomSnap = await tx.get(_rooms.doc(roomId));
        if (!roomSnap.exists) return;
        final room = RoomModel.fromFirestore(roomSnap);
        if (room.phase == GamePhase.finished) return;

        final blockUntil = room.revealCount + EconomyConfig.stunCardBlockTurns;
        tx.update(_firestore.doc('users/$actorUid'), {
          'stunCardCount': FieldValue.increment(-1),
        });
        tx.update(_rooms.doc(roomId), {
          'blockedGuessers.$targetUid': blockUntil,
        });
        success = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('STUN', 'STUN_CARD_ERROR error=$e');
    }
    if (success) {
      QaLoggerService.instance.log('STUN',
          'STUN_CARD_APPLIED actor=${actorUid.substring(0, actorUid.length.clamp(0, 6))} target=${targetUid.substring(0, targetUid.length.clamp(0, 6))}');
    }
    return success;
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
