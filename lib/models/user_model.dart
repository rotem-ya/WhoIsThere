import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String? photoUrl;
  final int totalPoints;
  final List<String> purchasedImageIds;
  final List<String> purchasedThemeIds;

  const UserModel({
    required this.id,
    required this.name,
    this.photoUrl,
    this.totalPoints = 0,
    this.purchasedImageIds = const [],
    this.purchasedThemeIds = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      totalPoints: data['totalPoints'] ?? 0,
      purchasedImageIds: List<String>.from(data['purchasedImageIds'] ?? []),
      purchasedThemeIds: List<String>.from(data['purchasedThemeIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'totalPoints': totalPoints,
        'purchasedImageIds': purchasedImageIds,
        'purchasedThemeIds': purchasedThemeIds,
      };

  UserModel copyWith({
    String? name,
    String? photoUrl,
    int? totalPoints,
    List<String>? purchasedImageIds,
    List<String>? purchasedThemeIds,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        totalPoints: totalPoints ?? this.totalPoints,
        purchasedImageIds: purchasedImageIds ?? this.purchasedImageIds,
        purchasedThemeIds: purchasedThemeIds ?? this.purchasedThemeIds,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        photoUrl,
        totalPoints,
        purchasedImageIds,
        purchasedThemeIds,
      ];
}
