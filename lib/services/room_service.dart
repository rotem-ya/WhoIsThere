import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

const List<String> _botNames = [
  'אריאל', 'נועה', 'עמית', 'שירה', 'דניאל', 'מאיה', 'ליאור', 'איתי',
  'שני', 'אדם', 'מור', 'רועי', 'תמר', 'אורי', 'גל', 'עידו',
  'ירדן', 'ניר', 'לירון', 'דנה', 'אייל', 'הילה', 'ניב', 'שחר',
  'יעל', 'בן', 'אורן', 'מיכל', 'יוסף', 'אבי',
  'רוני', 'קרן', 'עמיר', 'ליאת', 'אלון', 'ענבל', 'אסף', 'טל',
  'עינב', 'יובל', 'נעמה', 'גיא', 'אלה', 'דור', 'שלומית', 'יאיר',
  'ורד', 'ארז', 'שקד', 'יהונתן', 'חן', 'אביב', 'שמשון', 'נטע',
  'איל', 'כרמל', 'אלי', 'נדב', 'ספיר', 'שלום', 'אנה', 'עמנואל',
  'לי', 'מתן', 'רינת', 'ידידיה', 'נוי', 'מרב', 'עוז', 'ינאי',
  'יפית', 'שי', 'אורית', 'ידין', 'זיו', 'רחל', 'שלמה', 'מרים',
  'גבריאל', 'אסתר', 'נחום', 'ברק', 'חגית', 'ישי', 'ריקי', 'אביחי',
  'כוכב', 'אילן', 'פנינה', 'רם', 'אנת', 'ניצן', 'אפרת', 'שוקי',
  'יגאל', 'הגר', 'עמוס', 'מזל', 'ציון', 'שושנה',
];

final Random _botRng = Random();

/// Picks a random bot name, avoiding any already in [used] so a single room
/// never shows the same fake player twice and the roster feels fresh every
/// match (previously the name was chosen by index, so a solo game was always
/// "עמית").
String _randomBotName(Set<String> used) {
  final pool = _botNames.where((n) => !used.contains(n)).toList();
  final source = pool.isNotEmpty ? pool : _botNames;
  return source[_botRng.nextInt(source.length)];
}

/// Believable, varied profile for a bot so each one looks like a distinct real
/// player — a different "places discovered" badge and loosely-correlated points.
({int discoveredCount, int totalPoints}) _randomBotProfile() {
  final discovered = _botRng.nextInt(41); // 0..40 discovered places
  // ~60-130 points per discovery plus jitter, so any rank-based display varies
  // naturally across the roster instead of every bot reading as a beginner.
  final totalPoints =
      discovered * (60 + _botRng.nextInt(70)) + _botRng.nextInt(120);
  return (discoveredCount: discovered, totalPoints: totalPoints);
}

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

  // Returns reveal countdown ring duration: fast early, slower as image becomes clearer.
  static int _revealTimerMs(int revealedCount, int totalTiles) {
    if (revealedCount < 3) return 3000;
    if (revealedCount < 13) return 6000;
    return 9000;
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
    'mahane_yehuda_market',
    'knesset',
    'israel_museum',
    'yad_vashem',
    'masada',
    'dead_sea',
    'ein_gedi',
    'ramon_crater',
    'timna_park',
    'dolphin_reef',
    'mount_hermon',
    'sea_of_galilee',
    'old_acre',
    'bahai_gardens',
    'haifa_port',
    'old_jaffa',
    'azrieli_towers',
    'stalactite_cave',
    'gan_hashlosha',
    'banias_waterfall',
    'rosh_hanikra',
    'caesarea',
    'tel_aviv_port',
    'cave_of_the_patriarchs',
    'mount_tabor',
    'hexagon_pool',
    'agamon_hahula',
    'mount_meron',
    'montfort',
    'mini_israel',
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
    bool isPublicRoom = false,
  }) async {
    final code = RoomCodeGenerator.generate();
    final docRef = _rooms.doc();

    // Ensure the Firestore SDK has the current user's token before any write.
    // After an anonymous→Google auth transition the SDK can briefly hold a
    // stale token; forcing a refresh here prevents permission-denied on the
    // first room creation attempt.
    final currentUser = FirebaseAuth.instance.currentUser;
    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_TOKEN_CHECK '
        'hostId=$hostId sdkUid=${currentUser?.uid} anonymous=${currentUser?.isAnonymous}');
    if (currentUser != null) {
      try { await currentUser.getIdToken(true); } catch (_) {}
    }

    // CRITICAL: the room's hostId field must equal request.auth.uid or the
    // Firestore create rule rejects the write. Callers pass hostId from a
    // cached UserModel that can lag the live SDK uid after an anonymous→Google
    // auth transition (the cached id stays on the old anonymous uid). Reconcile
    // against the live SDK uid here — makes room creation self-correcting.
    final effectiveHostId = currentUser?.uid ?? hostId;
    if (effectiveHostId != hostId) {
      QaLoggerService.instance.log('ROOM',
          'CREATE_ROOM_HOSTID_RECONCILED stale=$hostId live=$effectiveHostId');
    }

    // Read the host's selected card skin, total points and discovered count
    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_USER_READ hostId=$effectiveHostId');
    final userSnap = await _firestore.doc('users/$effectiveHostId').get();
    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_USER_READ_OK exists=${userSnap.exists}');
    final cardSkinId = (userSnap.data()?['selectedCardSkin'] as String?) ?? 'default';
    final hostTotalPoints = (userSnap.data()?['totalPoints'] as int?) ?? 0;
    final hostDiscoveredCount =
        (userSnap.data()?['discoveredImageIds'] as List?)?.length ?? 0;
    final hostRound = await computePlayerRound(effectiveHostId);

    final host = PlayerModel(
      id: effectiveHostId,
      name: hostName,
      photoUrl: hostPhotoUrl,
      score: 0,
      totalPoints: hostTotalPoints,
      discoveredCount: hostDiscoveredCount,
      playerRound: hostRound,
      isHost: true,
    );

    final players = <String, PlayerModel>{effectiveHostId: host};

    final usedBotNames = <String>{host.name};
    for (int i = 2; i <= playerCount; i++) {
      final virtualId = 'virtual_${i}_${docRef.id}';
      final name = _randomBotName(usedBotNames);
      usedBotNames.add(name);
      final profile = _randomBotProfile();
      players[virtualId] = PlayerModel(
        id: virtualId,
        name: name,
        score: 0,
        isBot: true,
        discoveredCount: profile.discoveredCount,
        totalPoints: profile.totalPoints,
      );
    }

    // For public quick-match rooms, pre-pick the image now so the waiting room is
    // discoverable by exposure. matchExposureCount = the host's exposure to that
    // image; only same-exposure real players will be matched into this room.
    String? preImageId;
    int matchExposure = 0;
    if (isPublicRoom) {
      final images = await _loadLocalImages();
      if (images.isNotEmpty) {
        final img = await _pickSmartImage(images, players);
        preImageId = img.id;
        final hostExp = await _getExposureCounts(effectiveHostId);
        matchExposure = hostExp[img.id] ?? 0;
        QaLoggerService.instance.log('MATCH',
            'CREATE_MATCH_ROOM img=$preImageId hostExposure=$matchExposure');
      }
    }

    final room = RoomModel(
      id: docRef.id,
      code: code,
      hostId: effectiveHostId,
      players: players,
      createdAt: DateTime.now(),
      entryFee: entryFee,
      cardSkinId: cardSkinId,
      isPublicRoom: isPublicRoom,
      playerRound: hostRound,
      selectedImageId: preImageId,
      matchExposureCount: matchExposure,
    );

    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_WRITE id=${docRef.id}');
    await docRef.set(room.toMap());
    QaLoggerService.instance.log('ROOM', 'CREATE_ROOM_WRITE_OK');
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
    final joiningRound = await computePlayerRound(userId);

    final newPlayer = PlayerModel(
      id: userId,
      name: userName,
      photoUrl: userPhotoUrl,
      score: 0,
      totalPoints: joiningTotalPoints,
      discoveredCount: joiningDiscoveredCount,
      playerRound: joiningRound,
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

    final usedNames = room.players.values.map((p) => p.name).toSet();
    final profile = _randomBotProfile();
    final botPlayer = PlayerModel(
      id: virtualId,
      name: _randomBotName(usedNames),
      score: 0,
      isBot: true,
      discoveredCount: profile.discoveredCount,
      totalPoints: profile.totalPoints,
    );
    await _rooms.doc(roomId).update({
      'players.$virtualId': botPlayer.toMap(),
    });
  }

  /// Finds a waiting public room for quick match where playerRound matches.
  /// Requires Firestore composite index: phase + isPublicRoom + playerRound + createdAt
  Future<RoomModel?> findPublicRoom(int playerRound) async {
    try {
      final snap = await _rooms
          .where('phase', isEqualTo: GamePhase.waiting.name)
          .where('isPublicRoom', isEqualTo: true)
          .where('playerRound', isEqualTo: playerRound)
          .orderBy('createdAt')
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final room = RoomModel.fromFirestore(snap.docs.first);
      if (room.players.length >= GameConstants.maxPlayers) return null;
      return room;
    } catch (_) {
      return null;
    }
  }

  /// Public accessor for a user's per-image exposure counts (for matchmaking).
  Future<Map<String, int>> exposureCountsFor(String uid) => _getExposureCounts(uid);

  /// Quick-match by exposure: finds a waiting public room whose image the joining
  /// player has seen the SAME number of times as the host (room.matchExposureCount).
  /// Uses an equality-only query (no composite index needed) and filters locally.
  Future<RoomModel?> findMatchRoom(Map<String, int> myExposure) async {
    try {
      final snap = await _rooms
          .where('phase', isEqualTo: GamePhase.waiting.name)
          .where('isPublicRoom', isEqualTo: true)
          .limit(10)
          .get();
      for (final doc in snap.docs) {
        final room = RoomModel.fromFirestore(doc);
        if (room.players.length >= GameConstants.maxPlayers) continue;
        final imgId = room.selectedImageId;
        if (imgId == null || imgId.isEmpty) continue;
        final myExp = myExposure[imgId] ?? 0;
        if (myExp == room.matchExposureCount) {
          QaLoggerService.instance.log('MATCH',
              'MATCH_ROOM_FOUND room=${room.id.substring(0, room.id.length.clamp(0, 6))} img=$imgId exposure=$myExp');
          return room;
        }
      }
      QaLoggerService.instance.log('MATCH', 'MATCH_ROOM_NONE candidates=${snap.docs.length}');
      return null;
    } catch (e) {
      QaLoggerService.instance.log('MATCH', 'MATCH_ROOM_ERROR error=$e');
      return null;
    }
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
    // Reuse the image pre-picked at room creation (public quick-match rooms) so
    // the game image matches the one matchmaking paired players on. Falls back to
    // a fresh pick for rooms that don't have one yet.
    final existingId = room.selectedImageId;
    final image = (existingId != null && existingId.isNotEmpty)
        ? images.firstWhere((i) => i.id == existingId, orElse: () => images.first)
        : await _pickSmartImage(images, room.players);
    await _rooms.doc(roomId).update({'selectedImageId': image.id});
    // Start the game first (it rewrites the whole players map), THEN record
    // priorExposureCount via field-path so it isn't clobbered by _startGame.
    await _startGame(roomId, room, Difficulty.easy);
    await _recordPriorExposure(roomId, room.players, image.id);
    await _recordExposureForAll(room.players, image.id);
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

    final imageId = room.selectedImageId;
    // Start the game first (it rewrites the whole players map), THEN record
    // priorExposureCount via field-path so it isn't clobbered by _startGame.
    await _startGame(roomId, room, difficulty);
    if (imageId != null && imageId.isNotEmpty) {
      await _recordPriorExposure(roomId, room.players, imageId);
      await _recordExposureForAll(room.players, imageId);
    }
  }

  // ── Exposure history helpers ──────────────────────────────────

  /// Returns the player's current round: min exposure count across all active images.
  /// Round 0 = hasn't seen all images even once. Round N = completed N full cycles.
  Future<int> computePlayerRound(String uid) async {
    final exp = await _getExposureCounts(uid);
    if (exp.isEmpty) return 0;
    final images = await _loadLocalImages();
    if (images.isEmpty) return 0;
    return images.map((img) => exp[img.id] ?? 0).reduce(min);
  }

  /// Picks the next image so that, per player:
  ///  • an image never repeats until the whole pool has cycled once
  ///    (tracked via the `__cycleSeen` set, not raw exposure counts — so a
  ///    late-added image is shown once and then waits its turn, never
  ///    "catching up" by repeating), and
  ///  • brand-new images (never seen) jump the queue: they appear before any
  ///    already-seen image returns for another cycle.
  Future<GameImageModel> _pickSmartImage(
    List<GameImageModel> images,
    Map<String, PlayerModel> players,
  ) async {
    final realIds = players.entries
        .where((e) => !e.value.isBot)
        .map((e) => e.key)
        .toList();

    if (realIds.isEmpty) {
      final r = images[Random().nextInt(images.length)];
      QaLoggerService.instance.log('IMG', 'PICK_RANDOM_NOREAL chosen=${r.id} pool=${images.length}');
      return r;
    }

    try {
      final allIds = images.map((img) => img.id).toSet();
      final raws = await Future.wait(realIds.map(_getExposureRaw));

      // Per-player view: exposure counts, this-cycle "seen" set, last image.
      final counts = <Map<String, int>>[];
      final cycleSeen = <Set<String>>[];
      final lasts = <String?>[];
      for (final raw in raws) {
        final c = <String, int>{};
        for (final e in raw.entries) {
          if (!e.key.startsWith('__')) c[e.key] = (e.value as num?)?.toInt() ?? 0;
        }
        var seen = (raw['__cycleSeen'] as List?)
                ?.map((x) => x.toString())
                .toSet()
                .intersection(allIds) ??
            <String>{};
        // Pool already fully covered → start a fresh cycle.
        if (seen.length >= allIds.length) seen = <String>{};
        counts.add(c);
        cycleSeen.add(seen);
        lasts.add(raw['__last'] as String?);
      }

      // Score every image across all real players. Ranking priority:
      //   fresh-this-cycle → brand-new → not-just-shown → least-seen → random.
      final scored = images.map((img) {
        int fresh = 0, isNew = 0, notLast = 0, totalExp = 0;
        for (var i = 0; i < realIds.length; i++) {
          if (!cycleSeen[i].contains(img.id)) fresh++;
          if ((counts[i][img.id] ?? 0) == 0) isNew++;
          if (lasts[i] != img.id) notLast++;
          totalExp += counts[i][img.id] ?? 0;
        }
        return (
          img: img,
          fresh: fresh,
          isNew: isNew,
          notLast: notLast,
          totalExp: totalExp
        );
      }).toList()
        ..shuffle(Random());

      scored.sort((a, b) {
        if (a.fresh != b.fresh) return b.fresh - a.fresh;
        if (a.isNew != b.isNew) return b.isNew - a.isNew;
        if (a.notLast != b.notLast) return b.notLast - a.notLast;
        return a.totalExp - b.totalExp;
      });
      final pick = scored.first;
      final freshPool = scored.where((s) => s.fresh == realIds.length).length;
      QaLoggerService.instance.log(
          'IMG',
          'PICK chosen=${pick.img.id} fresh=${pick.fresh}/${realIds.length} '
              'isNew=${pick.isNew} notLast=${pick.notLast} totalExp=${pick.totalExp} '
              'pool=${images.length} freshRemaining=$freshPool');
      return pick.img;
    } catch (e) {
      final r = images[Random().nextInt(images.length)];
      QaLoggerService.instance.log('IMG', 'PICK_FALLBACK_ERR chosen=${r.id} error=$e');
      return r;
    }
  }

  /// Raw exposure document: image-id counts plus reserved `__` cycle metadata.
  Future<Map<String, dynamic>> _getExposureRaw(String uid) async {
    try {
      final snap = await _firestore.doc('users/$uid/exposure_history/data').get();
      if (!snap.exists) return {};
      return snap.data() ?? {};
    } catch (e) {
      QaLoggerService.instance.log('IMG', 'EXPOSURE_READ_FAIL uid=${_short(uid)} error=$e');
      return {};
    }
  }

  static String _short(String id) =>
      id.length <= 6 ? id : id.substring(id.length - 6);

  Future<Map<String, int>> _getExposureCounts(String uid) async {
    final raw = await _getExposureRaw(uid);
    final out = <String, int>{};
    for (final e in raw.entries) {
      if (e.key.startsWith('__')) continue; // skip reserved cycle metadata
      out[e.key] = (e.value as num?)?.toInt() ?? 0;
    }
    return out;
  }

  /// Stores each real player's current exposure count for imageId in the room
  /// BEFORE incrementing it, so the UI can show "seen N times before".
  Future<void> _recordPriorExposure(
    String roomId,
    Map<String, PlayerModel> players,
    String imageId,
  ) async {
    final realIds = players.entries
        .where((e) => !e.value.isBot)
        .map((e) => e.key)
        .toList();
    if (realIds.isEmpty) return;
    try {
      final exposureMaps = await Future.wait(realIds.map(_getExposureCounts));
      final updates = <String, dynamic>{};
      for (int i = 0; i < realIds.length; i++) {
        final count = exposureMaps[i][imageId] ?? 0;
        updates['players.${realIds[i]}.priorExposureCount'] = count;
      }
      await _rooms.doc(roomId).update(updates);
    } catch (_) {}
  }

  /// Records exposure for every real player and AWAITS the writes. This must be
  /// awaited by callers before the round is considered started, otherwise the
  /// next `_pickSmartImage` can read a stale `exposure_history` (the image not
  /// yet marked in `__cycleSeen`) and repeat an image before the cycle is done.
  ///
  /// Exposure tracking is best-effort: a failure here (permission/network) must
  /// NEVER abort game start, so each write swallows its own error.
  Future<void> _recordExposureForAll(
    Map<String, PlayerModel> players,
    String imageId,
  ) async {
    await Future.wait([
      for (final entry in players.entries)
        if (!entry.value.isBot)
          _recordExposureForPlayer(entry.key, imageId).catchError((e) {
            QaLoggerService.instance.log(
                'IMG', 'EXPOSURE_WRITE_FAIL uid=${_short(entry.key)} img=$imageId error=$e');
          }),
    ]);
  }

  /// Increments the player's exposure for [imageId], marks it seen in the
  /// current cycle, and resets the cycle once the whole pool has been shown.
  Future<void> _recordExposureForPlayer(String uid, String imageId) async {
    final images = await _loadLocalImages();
    final allIds = images.map((img) => img.id).toSet();
    final ref = _firestore.doc('users/$uid/exposure_history/data');
    var loggedSeen = 0;
    var loggedCount = 0;
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? <String, dynamic>{};
      final current = (data[imageId] as num?)?.toInt() ?? 0;
      var seen = (data['__cycleSeen'] as List?)
              ?.map((x) => x.toString())
              .toSet()
              .intersection(allIds) ??
          <String>{};
      seen.add(imageId);
      // Whole pool shown → close the cycle so the next round starts fresh.
      // (Re-showing this image immediately is prevented by the `__last` guard.)
      if (seen.length >= allIds.length) seen = <String>{};
      loggedSeen = seen.length;
      loggedCount = current + 1;
      tx.set(ref, {
        imageId: current + 1,
        '__cycleSeen': seen.toList(),
        '__last': imageId,
      }, SetOptions(merge: true));
    });
    QaLoggerService.instance.log(
        'IMG',
        'EXPOSURE_OK uid=${_short(uid)} img=$imageId count=$loggedCount '
            'cycleSeen=$loggedSeen/${allIds.length}');
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
          if (before < entryFee) return; // insufficient — UI should have blocked this
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
        if (before < room.entryFee) return; // insufficient — UI should have blocked this
        final after = before - room.entryFee;

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

        // ── Phase 1: no pending tile → pick one and start countdown ─
        final rng = Random();
        final revealedSet = room.placedPieces.keys.toSet();
        final pieceIndex = _pickCheckerboardTile(
          room.availablePieceIndices,
          revealedSet,
          room.gridSize,
          rng,
        );
        final ringMs = _revealTimerMs(room.placedPieces.length, room.gridSize * room.gridSize);

        tx.update(_rooms.doc(roomId), {
          'pendingRevealTileIndex': pieceIndex,
          'revealDeadlineMs': now + ringMs,
          'revealCycleId': FieldValue.increment(1),
        });
        QaLoggerService.instance.log('REVEAL',
            'AUTO_REVEAL_PENDING pieceIndex=$pieceIndex countdownMs=$ringMs revealed=${room.placedPieces.length}');
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

        final allowedPhase = room.turnPhase == TurnPhase.guessOpportunity ||
            room.turnPhase == TurnPhase.revealTurn;
        if (!allowedPhase) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=enterGuessMode reason=wrong_phase phase=${room.turnPhase.name}');
          return;
        }
        // In guessOpportunity: check slot is unclaimed and deadline not expired
        if (room.turnPhase == TurnPhase.guessOpportunity) {
          if (room.guessOpportunityPlayerId != null) {
            QaLoggerService.instance.log('TURN',
                'TX_ABORT name=enterGuessMode reason=already_claimed player=${room.guessOpportunityPlayerId}');
            return;
          }
          final deadline = room.guessOpportunityDeadlineMs;
          if (deadline != null && now >= deadline) {
            QaLoggerService.instance.log('TURN', 'TX_ABORT name=enterGuessMode reason=deadline_expired');
            return;
          }
        }
        if (room.isBlockedFromGuessing(userId)) {
          QaLoggerService.instance.log('TURN',
              'TX_ABORT name=enterGuessMode reason=player_blocked uid=${userId.substring(0, userId.length.clamp(0, 6))} blockedUntil=${room.blockedGuessers[userId]}');
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
          // Floor the deduction at the available balance so the wallet can
          // never go negative (mirrors the wrong-guess penalty clamp below).
          actualCost = claimCost.clamp(0, coinsBefore);
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
        // When entering from revealTurn: also pause the pending tile countdown
        tx.update(_rooms.doc(roomId), {
          'turnPhase': TurnPhase.guessMode.name,
          'guessOpportunityPlayerId': userId,
          'guessModePlayerId': userId,
          'guessModeDeadlineMs': now + 20000,
          'guessClaimCounts.$userId': claimCount + 1,
          if (actualCost > 0) 'potTotal': FieldValue.increment(actualCost),
          if (room.turnPhase == TurnPhase.revealTurn) ...{
            'pendingRevealTileIndex': FieldValue.delete(),
            'revealDeadlineMs': FieldValue.delete(),
          },
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

      // Parallel guessing: any live, non-blocked player may submit at any time.
      // The first correct answer wins the race — this transaction is the arbiter.
      if (room.phase != GamePhase.playing) {
        QaLoggerService.instance.log('GUESS',
            'TX_ABORT name=submitAnswer reason=not_playing phase=${room.phase.name}');
        return;
      }
      final nowBlockMs = DateTime.now().millisecondsSinceEpoch;
      final timeBlocked = (room.guessBlockedUntilMs[userId] ?? 0) > nowBlockMs;
      if (room.isBlockedFromGuessing(userId) || timeBlocked) {
        QaLoggerService.instance.log('GUESS',
            'TX_ABORT name=submitAnswer reason=blocked uid=${_short(userId)}');
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
      // Bots have no wallet document — skip wallet operations entirely
      if (userId.startsWith('virtual_')) {
        final currentWrongCountBot = room.wrongGuessCounts[userId] ?? 0;
        // Parallel mode: a wrong guess penalises/blocks only this player; it does
        // NOT advance the turn or restart the reveal cadence (which keeps running
        // on its own timers so other players can still race).
        tx.update(_rooms.doc(roomId), {
          'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
          'guessCount': FieldValue.increment(1),
          'wrongGuessCounts.$userId': currentWrongCountBot + 1,
          'blockedGuessers.$userId': room.revealCount + EconomyConfig.wrongGuessBlockTurns,
          'players.$userId.score': FieldValue.increment(-difficulty.wrongGuessPenalty),
        });
        QaLoggerService.instance.log('GUESS',
            'TX_COMMIT name=submitAnswer result=wrong latencyMs=${DateTime.now().millisecondsSinceEpoch - txStartMs}');
        return;
      }

      final walletDoc = await tx.get(_walletRef(userId));
      final wallet = walletDoc.exists
          ? UserEconomyModel.fromFirestore(
              userId, walletDoc.data() as Map<String, dynamic>)
          : null;
      final before = wallet?.coins ?? 0;
      final currentWrongCount = room.wrongGuessCounts[userId] ?? 0;

      final wrongPenalty = EconomyConfig.baseWrongGuessPenalty +
          (currentWrongCount * EconomyConfig.wrongGuessPenaltyIncrement);
      final actualPenalty = wrongPenalty.clamp(0, before);
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

      // Parallel mode: a wrong guess penalises/blocks only this player; the reveal
      // cadence and turn order are left untouched so others can keep racing.
      final updates = <String, dynamic>{
        'lastGuessEvent': {'playerId': userId, 'guess': guess, 'isCorrect': false},
        'guessCount': FieldValue.increment(1),
        'wrongGuessCounts.$userId': currentWrongCount + 1,
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

  /// Blocks [targetUid] from guessing for [durationMs] milliseconds.
  /// Decrements actor's guessBlock5Count or guessBlock10Count.
  Future<bool> applyGuessBlockCard({
    required String roomId,
    required String actorUid,
    required String targetUid,
    required bool is10s,
  }) async {
    final field = is10s ? 'guessBlock10Count' : 'guessBlock5Count';
    final duration = is10s ? EconomyConfig.guessBlock10DurationMs : EconomyConfig.guessBlock5DurationMs;
    bool success = false;
    try {
      await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(_firestore.doc('users/$actorUid'));
        if (!userSnap.exists) return;
        final count = (userSnap.data() as Map<String, dynamic>)[field] as int? ?? 0;
        if (count <= 0) return;
        final roomSnap = await tx.get(_rooms.doc(roomId));
        if (!roomSnap.exists) return;
        final room = RoomModel.fromFirestore(roomSnap);
        if (room.phase == GamePhase.finished) return;
        final unblockAt = DateTime.now().millisecondsSinceEpoch + duration;
        tx.update(_firestore.doc('users/$actorUid'), {field: FieldValue.increment(-1)});
        tx.update(_rooms.doc(roomId), {'guessBlockedUntilMs.$targetUid': unblockAt});
        success = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('CARD', 'GUESS_BLOCK_ERROR error=$e');
    }
    if (success) {
      QaLoggerService.instance.log('CARD',
          'GUESS_BLOCK_APPLIED is10s=$is10s actor=${actorUid.substring(0, actorUid.length.clamp(0, 6))} target=${targetUid.substring(0, targetUid.length.clamp(0, 6))}');
    }
    return success;
  }

  /// Activates blackout on [targetUid]'s image area for [blackoutDurationMs] ms.
  Future<bool> applyBlackoutCard({
    required String roomId,
    required String actorUid,
    required String targetUid,
  }) async {
    bool success = false;
    try {
      await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(_firestore.doc('users/$actorUid'));
        if (!userSnap.exists) return;
        final count = (userSnap.data() as Map<String, dynamic>)['blackoutCardCount'] as int? ?? 0;
        if (count <= 0) return;
        final roomSnap = await tx.get(_rooms.doc(roomId));
        if (!roomSnap.exists) return;
        final room = RoomModel.fromFirestore(roomSnap);
        if (room.phase == GamePhase.finished) return;
        final expiresAt = DateTime.now().millisecondsSinceEpoch + EconomyConfig.blackoutDurationMs;
        tx.update(_firestore.doc('users/$actorUid'), {'blackoutCardCount': FieldValue.increment(-1)});
        tx.update(_rooms.doc(roomId), {'blackoutActiveUntilMs.$targetUid': expiresAt});
        success = true;
      });
    } catch (e) {
      QaLoggerService.instance.log('CARD', 'BLACKOUT_ERROR error=$e');
    }
    if (success) {
      QaLoggerService.instance.log('CARD',
          'BLACKOUT_APPLIED actor=${actorUid.substring(0, actorUid.length.clamp(0, 6))} target=${targetUid.substring(0, targetUid.length.clamp(0, 6))}');
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
