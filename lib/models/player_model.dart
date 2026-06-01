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
      ];
}
