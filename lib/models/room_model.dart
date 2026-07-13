import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/game_categories.dart';
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
  final String selectedCategory;
  final List<String> turnOrder;
  final int currentTurnIndex;
  final Map<int, String> placedPieces; // pieceIndex -> userId
  final List<int> availablePieceIndices;
  final List<String> solvedLetters; // lowercase letters correctly guessed
  final List<String> letterCardGrantedPlayerIds;
  final String? winnerId;
  final Map<String, dynamic>? lastGuessEvent;
  final Map<String, dynamic>? lastReaction; // {playerId, emoji, ts}
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
  final bool isPublicRoom;
  final int playerRound;
  /// Quick-match key: the host's exposure count to [selectedImageId]. A real
  /// player is only matched into this room if THEIR exposure to the same image
  /// equals this value (same-exposure matchmaking).
  final int matchExposureCount;
  // Fast-game "heat": a sequence of quick rounds (one image per category). Empty
  // for the normal single-round game. [heatRoundIndex] is the 0-based current round.
  final List<String> heatCategories;
  final List<String> heatImageIds;
  // Parallel to [heatImageIds]: each round's answer text, precomputed at heat-
  // build time so the letter-turn mechanic never needs an async image lookup
  // inside a Firestore transaction when advancing rounds.
  final List<String> heatAnswers;
  final int heatRoundIndex;
  // חי-צומח-דומם: ids של שחקנים אנושיים שהצביעו להחליף את הפריט הנוכחי (כשאף אחד
  // לא יודע את התשובה). בוטים ניטרליים — לא מצביעים ולא נספרים. מתאפס בכל החלפת
  // פריט / מעבר סבב.
  final List<String> skipVotes;
  // Friends-mode heat topic picks: playerId → list of chosen categoryIds.
  // Each player picks 1; when there are <3 players the host picks the extra
  // topics so the heat still has ≥3 rounds. Resolved into [heatCategories] when
  // the host starts. Empty for quick-match (random topics).
  final Map<String, List<String>> topicChoices;
  // Friends games: player ids that have already claimed their placement reward
  // (idempotency guard so the 20/5 coin gift is paid at most once each).
  final List<String> placementPaidPlayerIds;
  // Set on a FINISHED room when a player taps "play again": points at the fresh
  // room the group can rejoin. Lets the rest of the win screen offer "join
  // rematch". Null until someone starts a rematch. Friends games only.
  final String? rematchRoomId;

  // ── Heat round interlude — short synced pause between heat rounds ─────────
  // Stamped by the round-advance transaction: until this wall-clock ms every
  // client shows the finished image + its answer + who solved it, so the next
  // image is revealed to everyone together.
  final int? roundInterludeUntilMs;
  // Friends-game host setting: when false, the trick cards (guess blocks,
  // blackout, stun) are disabled for everyone in this room. Default true so
  // existing rooms and public games keep today's behavior.
  final bool tricksEnabled;
  // Set when this room was opened FOR a saved friends group ("קבוצה קבועה"):
  // the finished game's scores roll into that group's cumulative scoreboard.
  final String? groupId;
  final String? lastRoundImageId;
  // Display name of the round's solver; null when the board filled with no
  // correct guess.
  final String? lastRoundWinnerName;

  // ── Letters game (משחק האותיות) — Wordle-style image-reveal duel ──────────
  // Game mode discriminator. 'normal' is the classic/heat reveal game (default
  // so existing rooms deserialize unchanged); 'letters' is the turn-based
  // letter-guessing duel.
  final String mode;
  // The secret answer for the letters game — the Hebrew name of the chosen
  // image (selectedImageId). Null for non-letters rooms.
  final String? secretWord;
  // Per-player board state for the letters game (separate board per player):
  // uid → list of revealed tile indices on THAT player's board.
  final Map<String, List<int>> lettersRevealedTiles;
  // uid → list of letters that player has guessed (normalized), for keyboard
  // coloring (present/absent).
  final Map<String, List<String>> lettersGuessed;
  // uid → list of slot indices the player has correctly filled (green). When a
  // player's solved-slot count equals the answer length they win (auto-win).
  final Map<String, List<int>> lettersSolvedSlots;

  // ── Letter-turn guessing (normal/heat/proverbs rooms) — additive, alongside
  // the tile reveal and free-text race. Off unless the host enables it, and
  // never active in a mode:'letters' room (that's the separate duel above).
  // Host toggle, mirrors tricksEnabled. Default false: existing/new rooms are
  // unaffected until a host opts in.
  final bool letterTurnEnabled;
  // Server-side snapshot of the CURRENT round's answer text, set only when
  // letterTurnEnabled — the transaction never trusts a client-supplied answer.
  // Null when the mechanic isn't active for this round.
  final String? letterTurnAnswer;
  // Shared (not per-player) board: slot indices revealed so far this round,
  // in the buildLettersPuzzle(letterTurnAnswer) index space.
  final List<int> letterTurnRevealedSlots;
  // Shared set of letters already tried this round (hit or miss) — greys out
  // the turn keyboard so nobody burns a turn re-guessing a tried letter.
  final List<String> letterTurnGuessedLetters;
  // Deadline for the current player's turn. Null when the mechanic isn't
  // active for this round.
  final int? letterTurnDeadlineMs;
  // Bumped on every accepted guess AND every timeout-skip — lets the client
  // dedup "already handled this exact turn" even when currentTurnIndex wraps
  // back to a value it already had.
  final int letterTurnCycleId;

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
    this.selectedCategory = GameCategories.israelPlaces,
    this.turnOrder = const [],
    this.currentTurnIndex = 0,
    this.placedPieces = const {},
    this.availablePieceIndices = const [],
    this.solvedLetters = const [],
    this.letterCardGrantedPlayerIds = const [],
    this.winnerId,
    this.lastGuessEvent,
    this.lastReaction,
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
    this.isPublicRoom = false,
    this.playerRound = 0,
    this.matchExposureCount = 0,
    this.heatCategories = const [],
    this.heatImageIds = const [],
    this.heatAnswers = const [],
    this.heatRoundIndex = 0,
    this.skipVotes = const [],
    this.topicChoices = const {},
    this.placementPaidPlayerIds = const [],
    this.rematchRoomId,
    this.roundInterludeUntilMs,
    this.tricksEnabled = true,
    this.groupId,
    this.lastRoundImageId,
    this.lastRoundWinnerName,
    this.mode = 'normal',
    this.secretWord,
    this.lettersRevealedTiles = const {},
    this.lettersGuessed = const {},
    this.lettersSolvedSlots = const {},
    this.letterTurnEnabled = false,
    this.letterTurnAnswer,
    this.letterTurnRevealedSlots = const [],
    this.letterTurnGuessedLetters = const [],
    this.letterTurnDeadlineMs,
    this.letterTurnCycleId = 0,
  });

  // True for the letters game (Wordle-style duel).
  bool get isLetters => mode == 'letters';

  // True for "זהו את הפתגם" — a heat game whose every round is the proverbs
  // category. Derived from the category (no new mode field): private rooms
  // carry it from creation, quick-match rooms from the pre-built heat.
  bool get isProverbs => selectedCategory == GameCategories.proverbs;

  // True when this room is a fast-game heat (more than one queued round).
  bool get isHeat => heatImageIds.length > 1;
  bool get isLastHeatRound => heatRoundIndex >= heatImageIds.length - 1;

  // ── דילוג/החלפת פריט בחי-צומח-דומם (הצבעת רוב) ──────────────────────────────
  // הצבעת דילוג מתאפשרת רק אחרי שנחשפו ≥30% מהמשבצות.
  static const double kSkipVoteMinRevealRatio = 0.30;
  // אפשר להציע החלפת פריט: היט פעיל, שלב משחק, ומעבר לסף החשיפה.
  bool skipVoteEligible(double revealRatio) =>
      isHeat &&
      phase == GamePhase.playing &&
      revealRatio >= kSkipVoteMinRevealRatio;
  // שחקנים אנושיים פעילים (לא בוטים, לא הודחו) — בסיס ספירת הרוב. בוטים ניטרליים.
  List<PlayerModel> get humanPlayers =>
      players.values.where((p) => !p.isBot && !p.isEliminated).toList();
  // רוב: יותר ממחצית האנושיים. 1→1, 2→2 (1-על-1 אמיתי), 3→2, 4→3.
  int get skipVoteThreshold => (humanPlayers.length ~/ 2) + 1;
  // מספר ההצבעות התקפות (רק שחקנים אנושיים פעילים נספרים).
  int get skipVoteCount {
    final humanIds = humanPlayers.map((p) => p.id).toSet();
    return skipVotes.where(humanIds.contains).length;
  }
  bool get skipVotePassed =>
      humanPlayers.isNotEmpty && skipVoteCount >= skipVoteThreshold;

  // Friends games are private (not public quick-match): free entry, per-game
  // scoring (not added to lifetime totalPoints), top-2 placement coin rewards.
  bool get isFriendsGame => !isPublicRoom;

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

  // Letter-turn guessing is live for this round only when the host enabled it
  // AND the round-reset already snapshotted an answer to guess against. Never
  // true for the separate letters-duel mode.
  bool get isLetterTurnActive =>
      !isLetters && letterTurnEnabled && letterTurnAnswer != null && letterTurnAnswer!.isNotEmpty;

  // Whose turn it is to guess a letter. Deliberately DERIVED from
  // [letterTurnCycleId] rather than sharing [currentTurnIndex] — that field is
  // already owned by the manual tile-reveal turn mechanic (see [revealPiece]),
  // which advances on its own unrelated schedule; sharing it would make the
  // letter turn silently jump to a different player whenever a tile reveal
  // happens. [turnOrder] itself (the seat order) is read-only here and safe
  // to share.
  String? get letterTurnPlayerId {
    final activeIds = turnOrder
        .where((id) => !(players[id]?.isEliminated ?? false))
        .toList();
    if (activeIds.isEmpty) return null;
    return activeIds[letterTurnCycleId % activeIds.length];
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
      selectedCategory:
          (data['selectedCategory'] as String?) ?? GameCategories.israelPlaces,
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
      lastReaction: data['lastReaction'] as Map<String, dynamic>?,
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
      isPublicRoom: data['isPublicRoom'] as bool? ?? false,
      playerRound: (data['playerRound'] as num?)?.toInt() ?? 0,
      matchExposureCount: (data['matchExposureCount'] as num?)?.toInt() ?? 0,
      heatCategories: List<String>.from(data['heatCategories'] ?? []),
      heatImageIds: List<String>.from(data['heatImageIds'] ?? []),
      heatAnswers: List<String>.from(data['heatAnswers'] ?? []),
      heatRoundIndex: (data['heatRoundIndex'] as num?)?.toInt() ?? 0,
      skipVotes: List<String>.from(data['skipVotes'] ?? const []),
      topicChoices: (data['topicChoices'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v as List? ?? const [])),
          ) ??
          const {},
      placementPaidPlayerIds:
          List<String>.from(data['placementPaidPlayerIds'] ?? const []),
      rematchRoomId: data['rematchRoomId'] as String?,
      roundInterludeUntilMs: (data['roundInterludeUntilMs'] as num?)?.toInt(),
      tricksEnabled: (data['tricksEnabled'] as bool?) ?? true,
      groupId: data['groupId'] as String?,
      lastRoundImageId: data['lastRoundImageId'] as String?,
      lastRoundWinnerName: data['lastRoundWinnerName'] as String?,
      mode: (data['mode'] as String?) ?? 'normal',
      secretWord: data['secretWord'] as String?,
      lettersRevealedTiles: (data['lettersRevealedTiles'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), List<int>.from(v as List? ?? const [])),
          ) ??
          const {},
      lettersGuessed: (data['lettersGuessed'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v as List? ?? const [])),
          ) ??
          const {},
      lettersSolvedSlots: (data['lettersSolvedSlots'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), List<int>.from(v as List? ?? const [])),
          ) ??
          const {},
      letterTurnEnabled: (data['letterTurnEnabled'] as bool?) ?? false,
      letterTurnAnswer: data['letterTurnAnswer'] as String?,
      letterTurnRevealedSlots:
          List<int>.from(data['letterTurnRevealedSlots'] ?? const []),
      letterTurnGuessedLetters:
          List<String>.from(data['letterTurnGuessedLetters'] ?? const []),
      letterTurnDeadlineMs: (data['letterTurnDeadlineMs'] as num?)?.toInt(),
      letterTurnCycleId: (data['letterTurnCycleId'] as num?)?.toInt() ?? 0,
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
        'selectedCategory': selectedCategory,
        'selectedDifficulty': selectedDifficulty?.name,
        'turnOrder': turnOrder,
        'currentTurnIndex': currentTurnIndex,
        'placedPieces': placedPieces.map((k, v) => MapEntry(k.toString(), v)),
        'availablePieceIndices': availablePieceIndices,
        'solvedLetters': solvedLetters,
        'letterCardGrantedPlayerIds': letterCardGrantedPlayerIds,
        'winnerId': winnerId,
        'lastGuessEvent': lastGuessEvent,
        'lastReaction': lastReaction,
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
        'isPublicRoom': isPublicRoom,
        'playerRound': playerRound,
        'matchExposureCount': matchExposureCount,
        'heatCategories': heatCategories,
        'heatImageIds': heatImageIds,
        'heatAnswers': heatAnswers,
        'heatRoundIndex': heatRoundIndex,
        'skipVotes': skipVotes,
        'topicChoices': topicChoices,
        'placementPaidPlayerIds': placementPaidPlayerIds,
        'rematchRoomId': rematchRoomId,
        if (roundInterludeUntilMs != null)
          'roundInterludeUntilMs': roundInterludeUntilMs,
        'tricksEnabled': tricksEnabled,
        if (groupId != null) 'groupId': groupId,
        if (lastRoundImageId != null) 'lastRoundImageId': lastRoundImageId,
        if (lastRoundWinnerName != null)
          'lastRoundWinnerName': lastRoundWinnerName,
        'mode': mode,
        if (secretWord != null) 'secretWord': secretWord,
        'lettersRevealedTiles': lettersRevealedTiles,
        'lettersGuessed': lettersGuessed,
        'lettersSolvedSlots': lettersSolvedSlots,
        'letterTurnEnabled': letterTurnEnabled,
        if (letterTurnAnswer != null) 'letterTurnAnswer': letterTurnAnswer,
        'letterTurnRevealedSlots': letterTurnRevealedSlots,
        'letterTurnGuessedLetters': letterTurnGuessedLetters,
        'letterTurnDeadlineMs': letterTurnDeadlineMs,
        'letterTurnCycleId': letterTurnCycleId,
      };

  RoomModel copyWith({
    Map<String, PlayerModel>? players,
    GamePhase? phase,
    Map<String, String>? imageVotes,
    Map<String, int>? difficultyVotes,
    String? selectedImageId,
    Difficulty? selectedDifficulty,
    String? selectedCategory,
    List<String>? turnOrder,
    int? currentTurnIndex,
    Map<int, String>? placedPieces,
    List<int>? availablePieceIndices,
    List<String>? solvedLetters,
    List<String>? letterCardGrantedPlayerIds,
    String? winnerId,
    Map<String, dynamic>? lastGuessEvent,
    Map<String, dynamic>? lastReaction,
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
    bool? isPublicRoom,
    int? playerRound,
    int? matchExposureCount,
    List<String>? heatCategories,
    List<String>? heatImageIds,
    List<String>? heatAnswers,
    int? heatRoundIndex,
    List<String>? skipVotes,
    Map<String, List<String>>? topicChoices,
    List<String>? placementPaidPlayerIds,
    String? rematchRoomId,
    int? roundInterludeUntilMs,
    bool? tricksEnabled,
    String? groupId,
    String? lastRoundImageId,
    String? lastRoundWinnerName,
    String? mode,
    String? secretWord,
    Map<String, List<int>>? lettersRevealedTiles,
    Map<String, List<String>>? lettersGuessed,
    Map<String, List<int>>? lettersSolvedSlots,
    bool? letterTurnEnabled,
    String? letterTurnAnswer,
    List<int>? letterTurnRevealedSlots,
    List<String>? letterTurnGuessedLetters,
    int? letterTurnDeadlineMs,
    int? letterTurnCycleId,
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
        selectedCategory: selectedCategory ?? this.selectedCategory,
        turnOrder: turnOrder ?? this.turnOrder,
        currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
        placedPieces: placedPieces ?? this.placedPieces,
        availablePieceIndices: availablePieceIndices ?? this.availablePieceIndices,
        solvedLetters: solvedLetters ?? this.solvedLetters,
        letterCardGrantedPlayerIds:
            letterCardGrantedPlayerIds ?? this.letterCardGrantedPlayerIds,
        winnerId: winnerId ?? this.winnerId,
        lastGuessEvent: lastGuessEvent ?? this.lastGuessEvent,
        lastReaction: lastReaction ?? this.lastReaction,
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
        isPublicRoom: isPublicRoom ?? this.isPublicRoom,
        playerRound: playerRound ?? this.playerRound,
        matchExposureCount: matchExposureCount ?? this.matchExposureCount,
        heatCategories: heatCategories ?? this.heatCategories,
        heatImageIds: heatImageIds ?? this.heatImageIds,
        heatAnswers: heatAnswers ?? this.heatAnswers,
        heatRoundIndex: heatRoundIndex ?? this.heatRoundIndex,
        skipVotes: skipVotes ?? this.skipVotes,
        topicChoices: topicChoices ?? this.topicChoices,
        placementPaidPlayerIds:
            placementPaidPlayerIds ?? this.placementPaidPlayerIds,
        rematchRoomId: rematchRoomId ?? this.rematchRoomId,
        roundInterludeUntilMs:
            roundInterludeUntilMs ?? this.roundInterludeUntilMs,
        tricksEnabled: tricksEnabled ?? this.tricksEnabled,
        groupId: groupId ?? this.groupId,
        lastRoundImageId: lastRoundImageId ?? this.lastRoundImageId,
        lastRoundWinnerName: lastRoundWinnerName ?? this.lastRoundWinnerName,
        mode: mode ?? this.mode,
        secretWord: secretWord ?? this.secretWord,
        lettersRevealedTiles: lettersRevealedTiles ?? this.lettersRevealedTiles,
        lettersGuessed: lettersGuessed ?? this.lettersGuessed,
        lettersSolvedSlots: lettersSolvedSlots ?? this.lettersSolvedSlots,
        letterTurnEnabled: letterTurnEnabled ?? this.letterTurnEnabled,
        letterTurnAnswer: letterTurnAnswer ?? this.letterTurnAnswer,
        letterTurnRevealedSlots:
            letterTurnRevealedSlots ?? this.letterTurnRevealedSlots,
        letterTurnGuessedLetters:
            letterTurnGuessedLetters ?? this.letterTurnGuessedLetters,
        letterTurnDeadlineMs: letterTurnDeadlineMs ?? this.letterTurnDeadlineMs,
        letterTurnCycleId: letterTurnCycleId ?? this.letterTurnCycleId,
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
        selectedCategory,
        turnOrder,
        currentTurnIndex,
        placedPieces,
        availablePieceIndices,
        solvedLetters,
        letterCardGrantedPlayerIds,
        winnerId,
        lastGuessEvent,
        lastReaction,
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
        isPublicRoom,
        playerRound,
        matchExposureCount,
        heatCategories,
        heatImageIds,
        heatAnswers,
        heatRoundIndex,
        skipVotes,
        topicChoices,
        placementPaidPlayerIds,
        rematchRoomId,
        roundInterludeUntilMs,
        lastRoundImageId,
        lastRoundWinnerName,
        mode,
        tricksEnabled,
        groupId,
        secretWord,
        lettersRevealedTiles,
        lettersGuessed,
        lettersSolvedSlots,
        letterTurnEnabled,
        letterTurnAnswer,
        letterTurnRevealedSlots,
        letterTurnGuessedLetters,
        letterTurnDeadlineMs,
        letterTurnCycleId,
      ];
}
