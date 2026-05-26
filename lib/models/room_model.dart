import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/game_constants.dart';
import 'player_model.dart';

class RoomModel extends Equatable {
  final String id;
  final String code;
  final String hostId;
  final Map<String, PlayerModel> players;
  final GamePhase phase;
  final Map<String, String> imageVotes;
  final Map<String, int> difficultyVotes;
  final String? selectedImageId;
  final Difficulty? selectedDifficulty;
  final List<String> turnOrder;
  final int currentTurnIndex;
  final Map<int, String> placedPieces; // pieceIndex -> userId
  final List<int> availablePieceIndices;
  final List<String> solvedLetters; // lowercase letters correctly guessed
  final List<String> letterCardGrantedPlayerIds;
  final String? winnerId;
  final Map<String, dynamic>? lastGuessEvent;
  final int guessCount;
  final DateTime createdAt;
  final TurnPhase turnPhase;
  final String? guessOpportunityPlayerId;
  final String? guessModePlayerId;
  final String? lastRevealedByPlayerId;
  final int? revealDeadlineMs;
  final int? guessOpportunityDeadlineMs;
  final int? guessModeDeadlineMs;
  final Map<String, int> wrongGuessCounts;
  final int revealCycleId;
  final int revealCount;
  final Map<String, int> blockedGuessers;
  final int entryFee;
  final int potTotal;
  final Map<String, int> guessClaimCounts;
  final List<String> entryFeePaidPlayerIds;
  final String cardSkinId;
  final int? pendingRevealTileIndex;
  final Map<String, int> guessBlockedUntilMs;   // uid → epoch ms when block expires
  final Map<String, int> blackoutActiveUntilMs;  // uid → epoch ms when blackout expires

  const RoomModel({
    required this.id,
    required this.code,
    required this.hostId,
    required this.players,
    this.phase = GamePhase.waiting,
    this.imageVotes = const {},
    this.difficultyVotes = const {},
    this.selectedImageId,
    this.selectedDifficulty,
    this.turnOrder = const [],
    this.currentTurnIndex = 0,
    this.placedPieces = const {},
    this.availablePieceIndices = const [],
    this.solvedLetters = const [],
    this.letterCardGrantedPlayerIds = const [],
    this.winnerId,
    this.lastGuessEvent,
    this.guessCount = 0,
    required this.createdAt,
    this.turnPhase = TurnPhase.revealTurn,
    this.guessOpportunityPlayerId,
    this.guessModePlayerId,
    this.lastRevealedByPlayerId,
    this.revealDeadlineMs,
    this.guessOpportunityDeadlineMs,
    this.guessModeDeadlineMs,
    this.wrongGuessCounts = const {},
    this.revealCycleId = 0,
    this.revealCount = 0,
    this.blockedGuessers = const {},
    this.entryFee = 0,
    this.potTotal = 0,
    this.guessClaimCounts = const {},
    this.entryFeePaidPlayerIds = const [],
    this.cardSkinId = 'default',
    this.pendingRevealTileIndex,
    this.guessBlockedUntilMs = const {},
    this.blackoutActiveUntilMs = const {},
  });

  bool isBlockedFromGuessing(String userId) {
    final blockedUntil = blockedGuessers[userId];
    if (blockedUntil == null) return false;
    return revealCount < blockedUntil;
  }

  String? get currentTurnUserId {
    final activePlayers = turnOrder
        .where((id) => !(players[id]?.isEliminated ?? false))
        .toList();
    if (activePlayers.isEmpty) return null;
    return activePlayers[currentTurnIndex % activePlayers.length];
  }

  String get imageId => selectedImageId ?? '';
  List<int> get revealedCells => placedPieces.keys.toList();
  int get gridSize => selectedDifficulty?.gridSize ?? 5;

  List<PlayerModel> get activePlayers =>
      players.values.where((p) => !p.isEliminated).toList();

  List<PlayerModel> get sortedPlayers {
    final list = players.values.toList();
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final playersData = data['players'] as Map<String, dynamic>? ?? {};
    final players = playersData.map(
      (k, v) => MapEntry(k, PlayerModel.fromMap(k, v as Map<String, dynamic>)),
    );

    final placedPiecesRaw = data['placedPieces'] as Map<String, dynamic>? ?? {};
    final placedPieces = placedPiecesRaw.map(
      (k, v) => MapEntry(int.parse(k), v as String),
    );

    final wrongGuessCountsRaw =
        data['wrongGuessCounts'] as Map<String, dynamic>? ?? {};
    final wrongGuessCounts =
        wrongGuessCountsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    final blockedGuessersRaw =
        data['blockedGuessers'] as Map<String, dynamic>? ?? {};
    final blockedGuessers =
        blockedGuessersRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    final guessClaimCountsRaw =
        data['guessClaimCounts'] as Map<String, dynamic>? ?? {};
    final guessClaimCounts =
        guessClaimCountsRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

    return RoomModel(
      id: doc.id,
      code: data['code'] ?? '',
      hostId: data['hostId'] ?? '',
      players: players,
      phase: GamePhase.values.firstWhere(
        (e) => e.name == data['phase'],
        orElse: () => GamePhase.waiting,
      ),
      imageVotes: Map<String, String>.from(data['imageVotes'] ?? {}),
      difficultyVotes: Map<String, int>.from(data['difficultyVotes'] ?? {}),
      selectedImageId: data['selectedImageId'],
      selectedDifficulty: data['selectedDifficulty'] != null
          ? Difficulty.values.firstWhere(
              (e) => e.name == data['selectedDifficulty'],
              orElse: () => Difficulty.easy,
            )
          : null,
      turnOrder: List<String>.from(data['turnOrder'] ?? []),
      currentTurnIndex: data['currentTurnIndex'] ?? 0,
      placedPieces: placedPieces,
      availablePieceIndices: List<int>.from(data['availablePieceIndices'] ?? []),
      solvedLetters: List<String>.from(data['solvedLetters'] ?? []),
      letterCardGrantedPlayerIds:
          List<String>.from(data['letterCardGrantedPlayerIds'] ?? []),
      winnerId: data['winnerId'],
      lastGuessEvent: data['lastGuessEvent'] as Map<String, dynamic>?,
      guessCount: data['guessCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      turnPhase: TurnPhase.values.firstWhere(
        (e) => e.name == data['turnPhase'],
        orElse: () => TurnPhase.revealTurn,
      ),
      guessOpportunityPlayerId: data['guessOpportunityPlayerId'] as String?,
      guessModePlayerId: data['guessModePlayerId'] as String?,
      lastRevealedByPlayerId: data['lastRevealedByPlayerId'] as String?,
      revealDeadlineMs: (data['revealDeadlineMs'] as num?)?.toInt(),
      guessOpportunityDeadlineMs:
          (data['guessOpportunityDeadlineMs'] as num?)?.toInt(),
      guessModeDeadlineMs: (data['guessModeDeadlineMs'] as num?)?.toInt(),
      wrongGuessCounts: wrongGuessCounts,
      revealCycleId: (data['revealCycleId'] as num?)?.toInt() ?? 0,
      revealCount: (data['revealCount'] as num?)?.toInt() ?? 0,
      blockedGuessers: blockedGuessers,
      entryFee: (data['entryFee'] as num?)?.toInt() ?? 0,
      potTotal: (data['potTotal'] as num?)?.toInt() ?? 0,
      guessClaimCounts: guessClaimCounts,
      entryFeePaidPlayerIds: List<String>.from(data['entryFeePaidPlayerIds'] ?? []),
      cardSkinId: data['cardSkinId'] as String? ?? 'default',
      pendingRevealTileIndex: (data['pendingRevealTileIndex'] as num?)?.toInt(),
      guessBlockedUntilMs: Map<String, dynamic>.from(
              data['guessBlockedUntilMs'] as Map? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      blackoutActiveUntilMs: Map<String, dynamic>.from(
              data['blackoutActiveUntilMs'] as Map? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'hostId': hostId,
        'players': players.map((k, v) => MapEntry(k, v.toMap())),
        'phase': phase.name,
        'imageVotes': imageVotes,
        'difficultyVotes': difficultyVotes,
        'selectedImageId': selectedImageId,
        'selectedDifficulty': selectedDifficulty?.name,
        'turnOrder': turnOrder,
        'currentTurnIndex': currentTurnIndex,
        'placedPieces': placedPieces.map((k, v) => MapEntry(k.toString(), v)),
        'availablePieceIndices': availablePieceIndices,
        'solvedLetters': solvedLetters,
        'letterCardGrantedPlayerIds': letterCardGrantedPlayerIds,
        'winnerId': winnerId,
        'lastGuessEvent': lastGuessEvent,
        'guessCount': guessCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'turnPhase': turnPhase.name,
        'guessOpportunityPlayerId': guessOpportunityPlayerId,
        'guessModePlayerId': guessModePlayerId,
        'lastRevealedByPlayerId': lastRevealedByPlayerId,
        'revealDeadlineMs': revealDeadlineMs,
        'guessOpportunityDeadlineMs': guessOpportunityDeadlineMs,
        'guessModeDeadlineMs': guessModeDeadlineMs,
        'wrongGuessCounts': wrongGuessCounts,
        'revealCycleId': revealCycleId,
        'revealCount': revealCount,
        'blockedGuessers': blockedGuessers,
        'entryFee': entryFee,
        'potTotal': potTotal,
        'guessClaimCounts': guessClaimCounts,
        'entryFeePaidPlayerIds': entryFeePaidPlayerIds,
        'cardSkinId': cardSkinId,
        if (pendingRevealTileIndex != null) 'pendingRevealTileIndex': pendingRevealTileIndex,
        'guessBlockedUntilMs': guessBlockedUntilMs,
        'blackoutActiveUntilMs': blackoutActiveUntilMs,
      };

  RoomModel copyWith({
    Map<String, PlayerModel>? players,
    GamePhase? phase,
    Map<String, String>? imageVotes,
    Map<String, int>? difficultyVotes,
    String? selectedImageId,
    Difficulty? selectedDifficulty,
    List<String>? turnOrder,
    int? currentTurnIndex,
    Map<int, String>? placedPieces,
    List<int>? availablePieceIndices,
    List<String>? solvedLetters,
    List<String>? letterCardGrantedPlayerIds,
    String? winnerId,
    Map<String, dynamic>? lastGuessEvent,
    int? guessCount,
    TurnPhase? turnPhase,
    String? guessOpportunityPlayerId,
    String? guessModePlayerId,
    String? lastRevealedByPlayerId,
    int? revealDeadlineMs,
    int? guessOpportunityDeadlineMs,
    int? guessModeDeadlineMs,
    Map<String, int>? wrongGuessCounts,
    int? revealCycleId,
    int? revealCount,
    Map<String, int>? blockedGuessers,
    int? entryFee,
    int? potTotal,
    Map<String, int>? guessClaimCounts,
    List<String>? entryFeePaidPlayerIds,
    String? cardSkinId,
    int? pendingRevealTileIndex,
    Map<String, int>? guessBlockedUntilMs,
    Map<String, int>? blackoutActiveUntilMs,
  }) =>
      RoomModel(
        id: id,
        code: code,
        hostId: hostId,
        players: players ?? this.players,
        phase: phase ?? this.phase,
        imageVotes: imageVotes ?? this.imageVotes,
        difficultyVotes: difficultyVotes ?? this.difficultyVotes,
        selectedImageId: selectedImageId ?? this.selectedImageId,
        selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
        turnOrder: turnOrder ?? this.turnOrder,
        currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
        placedPieces: placedPieces ?? this.placedPieces,
        availablePieceIndices: availablePieceIndices ?? this.availablePieceIndices,
        solvedLetters: solvedLetters ?? this.solvedLetters,
        letterCardGrantedPlayerIds:
            letterCardGrantedPlayerIds ?? this.letterCardGrantedPlayerIds,
        winnerId: winnerId ?? this.winnerId,
        lastGuessEvent: lastGuessEvent ?? this.lastGuessEvent,
        guessCount: guessCount ?? this.guessCount,
        createdAt: createdAt,
        turnPhase: turnPhase ?? this.turnPhase,
        guessOpportunityPlayerId:
            guessOpportunityPlayerId ?? this.guessOpportunityPlayerId,
        guessModePlayerId: guessModePlayerId ?? this.guessModePlayerId,
        lastRevealedByPlayerId:
            lastRevealedByPlayerId ?? this.lastRevealedByPlayerId,
        revealDeadlineMs: revealDeadlineMs ?? this.revealDeadlineMs,
        guessOpportunityDeadlineMs:
            guessOpportunityDeadlineMs ?? this.guessOpportunityDeadlineMs,
        guessModeDeadlineMs: guessModeDeadlineMs ?? this.guessModeDeadlineMs,
        wrongGuessCounts: wrongGuessCounts ?? this.wrongGuessCounts,
        revealCycleId: revealCycleId ?? this.revealCycleId,
        revealCount: revealCount ?? this.revealCount,
        blockedGuessers: blockedGuessers ?? this.blockedGuessers,
        entryFee: entryFee ?? this.entryFee,
        potTotal: potTotal ?? this.potTotal,
        guessClaimCounts: guessClaimCounts ?? this.guessClaimCounts,
        entryFeePaidPlayerIds: entryFeePaidPlayerIds ?? this.entryFeePaidPlayerIds,
        cardSkinId: cardSkinId ?? this.cardSkinId,
        pendingRevealTileIndex: pendingRevealTileIndex ?? this.pendingRevealTileIndex,
        guessBlockedUntilMs: guessBlockedUntilMs ?? this.guessBlockedUntilMs,
        blackoutActiveUntilMs: blackoutActiveUntilMs ?? this.blackoutActiveUntilMs,
      );

  @override
  List<Object?> get props => [
        id,
        code,
        hostId,
        players,
        phase,
        imageVotes,
        difficultyVotes,
        selectedImageId,
        selectedDifficulty,
        currentTurnIndex,
        placedPieces,
        solvedLetters,
        letterCardGrantedPlayerIds,
        winnerId,
        guessCount,
        turnPhase,
        guessOpportunityPlayerId,
        guessModePlayerId,
        lastRevealedByPlayerId,
        revealDeadlineMs,
        guessOpportunityDeadlineMs,
        guessModeDeadlineMs,
        wrongGuessCounts,
        revealCycleId,
        revealCount,
        blockedGuessers,
        entryFee,
        potTotal,
        guessClaimCounts,
        entryFeePaidPlayerIds,
        cardSkinId,
        pendingRevealTileIndex,
        guessBlockedUntilMs,
        blackoutActiveUntilMs,
      ];
}
