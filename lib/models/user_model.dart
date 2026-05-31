import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String? photoUrl;
  final String provider;
  final bool isGuest;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastSeenAt;
  final int totalPoints;
  final List<String> purchasedImageIds;
  final List<String> purchasedThemeIds;
  final List<String> discoveredImageIds;
  final int stunCardCount;
  final int guessBlock5Count;
  final int guessBlock10Count;
  final int blackoutCardCount;

  const UserModel({
    required this.id,
    required this.name,
    this.photoUrl,
    this.provider = 'anonymous',
    this.isGuest = true,
    this.createdAt,
    this.lastLoginAt,
    this.lastSeenAt,
    this.totalPoints = 0,
    this.purchasedImageIds = const [],
    this.purchasedThemeIds = const [],
    this.discoveredImageIds = const [],
    this.stunCardCount = 0,
    this.guessBlock5Count = 0,
    this.guessBlock10Count = 0,
    this.blackoutCardCount = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      provider: data['provider'] ?? 'anonymous',
      isGuest: data['isGuest'] ?? true,
      createdAt: _toDateTime(data['createdAt']),
      lastLoginAt: _toDateTime(data['lastLoginAt']),
      lastSeenAt: _toDateTime(data['lastSeenAt']),
      totalPoints: data['totalPoints'] ?? 0,
      purchasedImageIds: List<String>.from(data['purchasedImageIds'] ?? []),
      purchasedThemeIds: List<String>.from(data['purchasedThemeIds'] ?? []),
      discoveredImageIds: List<String>.from(data['discoveredImageIds'] ?? []),
      stunCardCount: (data['stunCardCount'] as int?) ?? 0,
      guessBlock5Count: (data['guessBlock5Count'] as int?) ?? 0,
      guessBlock10Count: (data['guessBlock10Count'] as int?) ?? 0,
      blackoutCardCount: (data['blackoutCardCount'] as int?) ?? 0,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'provider': provider,
        'isGuest': isGuest,
        'totalPoints': totalPoints,
        'purchasedImageIds': purchasedImageIds,
        'purchasedThemeIds': purchasedThemeIds,
        'discoveredImageIds': discoveredImageIds,
        // card counts written via FieldValue.increment in EconomyService
        // createdAt / lastLoginAt / lastSeenAt written via FieldValue in AuthService
      };

  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? provider,
    bool? isGuest,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastSeenAt,
    int? totalPoints,
    List<String>? purchasedImageIds,
    List<String>? purchasedThemeIds,
    List<String>? discoveredImageIds,
    int? stunCardCount,
    int? guessBlock5Count,
    int? guessBlock10Count,
    int? blackoutCardCount,
  }) =>
      UserModel(
        id: id,
        name: name ?? this.name,
        photoUrl: photoUrl ?? this.photoUrl,
        provider: provider ?? this.provider,
        isGuest: isGuest ?? this.isGuest,
        createdAt: createdAt ?? this.createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        totalPoints: totalPoints ?? this.totalPoints,
        purchasedImageIds: purchasedImageIds ?? this.purchasedImageIds,
        purchasedThemeIds: purchasedThemeIds ?? this.purchasedThemeIds,
        discoveredImageIds: discoveredImageIds ?? this.discoveredImageIds,
        stunCardCount: stunCardCount ?? this.stunCardCount,
        guessBlock5Count: guessBlock5Count ?? this.guessBlock5Count,
        guessBlock10Count: guessBlock10Count ?? this.guessBlock10Count,
        blackoutCardCount: blackoutCardCount ?? this.blackoutCardCount,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        photoUrl,
        provider,
        isGuest,
        totalPoints,
        purchasedImageIds,
        purchasedThemeIds,
        discoveredImageIds,
        stunCardCount,
        guessBlock5Count,
        guessBlock10Count,
        blackoutCardCount,
      ];
}
