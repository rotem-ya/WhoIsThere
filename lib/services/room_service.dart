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

  static const List<GameImageModel> _fallbackImages = [
    GameImageModel(
      id: 'local_eiffel_tower',
      name: 'מגדל אייפל',
      answer: 'מגדל אייפל',
      category: ImageCategory.landmark,
      imageUrl: 'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f?w=1200',
      thumbnailUrl: 'https://images.unsplash.com/photo-1511739001486-6bfe10ce785f?w=400',
    ),
    GameImageModel(
      id: 'local_colosseum',
      name: 'הקולוסיאום',
      answer: 'הקולוסיאום',
      category: ImageCategory.landmark,
      imageUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=1200',
      thumbnailUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400',
    ),
    GameImageModel(
      id: 'local_big_ben',
      name: 'ביג בן',
      answer: 'ביג בן',
      category: ImageCategory.landmark,
      imageUrl: 'https://images.unsplash.com/photo-1529655683826-aba9b3e77383?w=1200',
      thumbnailUrl: 'https://images.unsplash.com/photo-1529655683826-aba9b3e77383?w=400',
    ),
    GameImageModel(
      id: 'local_dead_sea',
      name: 'ים המלח',
      answer: 'ים המלח',
      category: ImageCategory.israeliLandmark,
      imageUrl: 'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=1200',
      thumbnailUrl: 'https://images.unsplash.com/photo-1544966503-7cc5ac882d5f?w=400',
    ),
    GameImageModel(
      id: 'local_western_wall',
      name: 'הכותל המערבי',
      answer: 'הכותל המערבי',
      category: ImageCategory.israeliLandmark,
      imageUrl: 'assets/images/places/western_wall.jpg',
      thumbnailUrl: 'assets/images/places/western_wall.jpg',
    ),
    GameImageModel(
      id: 'local_taj_mahal',
      name: 'טאג מאהל',
      answer: 'טאג מאהל',
      category: ImageCategory.landmark,
      imageUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=1200',
      thumbnailUrl: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?w=400',
    ),
  ];

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
    // Israel-only images that have local assets
    final pool = _fallbackImages
        .where((img) =>
            img.category == ImageCategory.israeliLandmark &&
            img.imageUrl.startsWith('assets/'))
        .toList();
    final image = pool.isNotEmpty
        ? pool[Random().nextInt(pool.length)]
        : _fallbackImages.first;
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

    final hostVotedCategory = room.imageVotes[hostId];
    final winningCategory = hostVotedCategory != null && winners.contains(hostVotedCategory)
        ? hostVotedCategory
        : winners[Random().nextInt(winners.length)];

    String selectedImageId;
    var query = await _firestore
        .collection('images')
        .where('isPremium', isEqualTo: false)
        .where('category', isEqualTo: winningCategory)
        .get();

    if (query.docs.isNotEmpty) {
      selectedImageId = query.docs[Random().nextInt(query.docs.length)].id;
    } else {
      final localImages = _fallbackImages
          .where((image) => image.category.name == winningCategory)
          .toList();
      final pool = localImages.isNotEmpty ? localImages : _fallbackImages;
      selectedImageId = pool[Random().nextInt(pool.length)].id;
    }

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

    final newHidden = room.availablePieceIndices.where((i) => i != pieceIndex).toList();
    final newScore = (room.players[userId]?.score ?? 0) + difficulty.placePiecePoints;

    await _rooms.doc(roomId).update({
      'placedPieces.${pieceIndex.toString()}': userId,
      'availablePieceIndices': newHidden,
      'players.$userId.score': newScore,
    });
  }

  Future<void> skipPiecePlacement({required String roomId}) async {
    final doc = await _rooms.doc(roomId).get();
    final room = RoomModel.fromFirestore(doc);
    await _rooms.doc(roomId).update({
      'currentTurnIndex': room.currentTurnIndex + 1,
    });
  }

  /// Letter-bank answer submission.
  /// Returns true if the answer is correct (room transitions to finished).
  /// Wrong answer: applies penalty, may eliminate; turn does NOT advance.
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
      });
      return true;
    }

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

  Future<List<GameImageModel>> getPublicImages() async {
    try {
      final query = await _firestore
          .collection('images')
          .where('isPremium', isEqualTo: false)
          .get();
      final images = query.docs.map(GameImageModel.fromFirestore).toList();
      return images.isEmpty ? _fallbackImages : images;
    } catch (_) {
      return _fallbackImages;
    }
  }

  Future<List<GameImageModel>> getAllImages() async {
    try {
      final query = await _firestore.collection('images').get();
      final images = query.docs.map(GameImageModel.fromFirestore).toList();
      return images.isEmpty ? _fallbackImages : images;
    } catch (_) {
      return _fallbackImages;
    }
  }

  Future<GameImageModel?> getImage(String imageId) async {
    final localMatch = _fallbackImages.where((image) => image.id == imageId);
    if (localMatch.isNotEmpty) return localMatch.first;

    final doc = await _firestore.collection('images').doc(imageId).get();
    if (!doc.exists) return _fallbackImages.first;
    return GameImageModel.fromFirestore(doc);
  }
}
