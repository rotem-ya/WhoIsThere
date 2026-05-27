import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_skin.dart';

/// Streams active card skins from Firestore `card_skins` collection,
/// ordered by `sortOrder`. Falls back to hardcoded list when empty.
///
/// Firestore document schema:
/// {
///   "nameHe": "שם העיצוב",
///   "price": 0,
///   "coverImageUrl": "https://storage.googleapis.com/...",  // optional
///   "previewImageUrl": "https://storage.googleapis.com/...", // optional
///   "active": true,
///   "sortOrder": 0
/// }
final firestoreSkinsProvider = StreamProvider<List<CardSkin>>((ref) {
  return FirebaseFirestore.instance
      .collection('card_skins')
      .where('active', isEqualTo: true)
      .orderBy('sortOrder')
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return kAvailableCardSkins;
    return snap.docs
        .map((doc) => CardSkin.fromFirestore(doc.id, doc.data()))
        .toList();
  });
});

/// Merged skin list: Firestore skins when available, otherwise hardcoded fallback.
final allSkinsProvider = Provider<List<CardSkin>>((ref) {
  final firestoreSkins = ref.watch(firestoreSkinsProvider);
  return firestoreSkins.valueOrNull ?? kAvailableCardSkins;
});
