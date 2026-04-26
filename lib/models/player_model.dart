import 'package:equatable/equatable.dart';

class PlayerModel extends Equatable {
  final String id;
  final String name;
  final String? photoUrl;
  final int score;
  final bool isEliminated;
  final bool isHost;
  final bool isBot;

  const PlayerModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.score,
    this.isEliminated = false,
    this.isHost = false,
    this.isBot = false,
  });

  factory PlayerModel.fromMap(String id, Map<String, dynamic> data) {
    return PlayerModel(
      id: id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      score: data['score'] ?? 0,
      isEliminated: data['isEliminated'] ?? false,
      isHost: data['isHost'] ?? false,
      isBot: data['isBot'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'score': score,
        'isEliminated': isEliminated,
        'isHost': isHost,
        'isBot': isBot,
      };

  PlayerModel copyWith({
    String? name,
    String? photoUrl,
    int? score,
    bool? isEliminated,
    bool? isHost,
    bool? isBot,
  }) =>
      PlayerModel(
        id: id,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        score: score ?? this.score,
        isEliminated: isEliminated ?? this.isEliminated,
        isHost: isHost ?? this.isHost,
        isBot: isBot ?? this.isBot,
      );

  @override
  List<Object?> get props => [id, name, score, isEliminated, isHost, isBot];
}
