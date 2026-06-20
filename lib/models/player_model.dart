import 'package:equatable/equatable.dart';

class PlayerModel extends Equatable {
  final String id;
  final String name;
  final String? photoUrl;
  final int score;
  final int totalPoints;
  final int letterCards;
  final bool isEliminated;
  final bool isHost;
  final bool isBot;
  final int discoveredCount;
  final int playerRound;
  final int priorExposureCount;
  // Equipped cosmetic avatar frame id ('none' = no ring).
  final String frameId;
  // Equipped cosmetic name colour/gradient id ('none' = default).
  final String nameStyleId;
  // Equipped cosmetic win-screen celebration effect id ('none' = default).
  final String winEffectId;
  // Chosen avatar face id ('auto' = generated face / photo).
  final String avatarId;

  const PlayerModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.score,
    this.totalPoints = 0,
    this.letterCards = 0,
    this.isEliminated = false,
    this.isHost = false,
    this.isBot = false,
    this.discoveredCount = 0,
    this.playerRound = 0,
    this.priorExposureCount = 0,
    this.frameId = 'none',
    this.nameStyleId = 'none',
    this.winEffectId = 'none',
    this.avatarId = 'auto',
  });

  factory PlayerModel.fromMap(String id, Map<String, dynamic> data) {
    return PlayerModel(
      id: id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      score: data['score'] ?? 0,
      totalPoints: data['totalPoints'] ?? 0,
      letterCards: data['letterCards'] ?? 0,
      isEliminated: data['isEliminated'] ?? false,
      isHost: data['isHost'] ?? false,
      isBot: data['isBot'] ?? false,
      discoveredCount: data['discoveredCount'] ?? 0,
      playerRound: data['playerRound'] ?? 0,
      priorExposureCount: data['priorExposureCount'] ?? 0,
      frameId: (data['frameId'] as String?) ?? 'none',
      nameStyleId: (data['nameStyleId'] as String?) ?? 'none',
      winEffectId: (data['winEffectId'] as String?) ?? 'none',
      avatarId: (data['avatarId'] as String?) ?? 'auto',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'score': score,
        'totalPoints': totalPoints,
        'letterCards': letterCards,
        'isEliminated': isEliminated,
        'isHost': isHost,
        'isBot': isBot,
        'discoveredCount': discoveredCount,
        'playerRound': playerRound,
        'priorExposureCount': priorExposureCount,
        'frameId': frameId,
        'nameStyleId': nameStyleId,
        'winEffectId': winEffectId,
        'avatarId': avatarId,
      };

  PlayerModel copyWith({
    String? name,
    String? photoUrl,
    int? score,
    int? totalPoints,
    int? letterCards,
    bool? isEliminated,
    bool? isHost,
    bool? isBot,
    int? discoveredCount,
    int? playerRound,
    int? priorExposureCount,
    String? frameId,
    String? nameStyleId,
    String? winEffectId,
    String? avatarId,
  }) =>
      PlayerModel(
        id: id,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        score: score ?? this.score,
        totalPoints: totalPoints ?? this.totalPoints,
        letterCards: letterCards ?? this.letterCards,
        isEliminated: isEliminated ?? this.isEliminated,
        isHost: isHost ?? this.isHost,
        isBot: isBot ?? this.isBot,
        discoveredCount: discoveredCount ?? this.discoveredCount,
        playerRound: playerRound ?? this.playerRound,
        priorExposureCount: priorExposureCount ?? this.priorExposureCount,
        frameId: frameId ?? this.frameId,
        nameStyleId: nameStyleId ?? this.nameStyleId,
        winEffectId: winEffectId ?? this.winEffectId,
        avatarId: avatarId ?? this.avatarId,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        score,
        totalPoints,
        letterCards,
        isEliminated,
        isHost,
        isBot,
        discoveredCount,
        playerRound,
        priorExposureCount,
        frameId,
        nameStyleId,
        winEffectId,
        avatarId,
      ];
}
