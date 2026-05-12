import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/game_constants.dart';
import '../widgets/game/letter_bank_input.dart' show normalizeHebrewFinals;

class GameImageModel extends Equatable {
  final String id;
  final String name;
  final String answer;
  final List<String> acceptedAnswers;
  final List<String> facts;
  final ImageCategory category;
  final bool isPremium;
  final int cost;
  final String imageUrl;
  final String thumbnailUrl;

  const GameImageModel({
    required this.id,
    required this.name,
    required this.answer,
    this.acceptedAnswers = const [],
    this.facts = const [],
    required this.category,
    this.isPremium = false,
    this.cost = 0,
    required this.imageUrl,
    required this.thumbnailUrl,
  });

  factory GameImageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameImageModel(
      id: doc.id,
      name: data['name'] ?? '',
      answer: data['answer'] ?? '',
      acceptedAnswers: List<String>.from(data['acceptedAnswers'] ?? []),
      category: ImageCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ImageCategory.place,
      ),
      isPremium: data['isPremium'] ?? false,
      cost: data['cost'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'answer': answer,
        'acceptedAnswers': acceptedAnswers,
        'category': category.name,
        'isPremium': isPremium,
        'cost': cost,
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
      };

  // Strict equality after Hebrew final-letter normalization and space stripping.
  // acceptedAnswers is intentionally ignored under the new mechanic.
  bool isCorrectAnswer(String guess) =>
      normalizeHebrewFinals(guess) == normalizeHebrewFinals(answer);

  @override
  List<Object?> get props => [id, name, answer, category, isPremium, cost];
}
