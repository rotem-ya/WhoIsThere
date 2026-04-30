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
  final List<String> solvedLetters;    // lowercase letters correctly guessed
  final String? winnerId;
  final DateTime createdAt;

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
    this.winnerId,
    required this.createdAt,
  });

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
      winnerId: data['winnerId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
        'winnerId': winnerId,
        'createdAt': Timestamp.fromDate(createdAt),
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
    String? winnerId,
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
        winnerId: winnerId ?? this.winnerId,
        createdAt: createdAt,
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
        winnerId,
      ];
}
