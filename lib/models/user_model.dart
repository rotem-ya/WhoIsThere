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
      ];
}
