import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/card_skin.dart';

/// Streams card skins from the `card_skins` Firestore collection and MERGES
/// them onto the bundled catalog — same live-content model as the cosmetics
/// catalog: an admin doc whose id matches a bundled skin OVERRIDES it (price /
/// cover image), `active:false` HIDES that skin, and a new id is appended.
///
/// The whole collection is streamed with no `where`/`orderBy` so it needs no
/// composite index and never drops docs that lack a field (the admin writes
/// no `sortOrder`). On any error the stream is empty → bundled fallback.
///
/// Firestore document schema (per doc, id = skin id):
/// { "nameHe": "...", "price": 0, "active": true,
///   "coverImageUrl": "https://…", "previewImageUrl": "https://…" }  // urls optional
final firestoreSkinsProvider = StreamProvider<List<CardSkin>>((ref) {
  return FirebaseFirestore.instance
      .collection('card_skins')
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return kAvailableCardSkins;
    final overrides = <String, CardSkin>{};
    final hidden = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['active'] == false) {
        hidden.add(doc.id);
        continue;
      }
      overrides[doc.id] = CardSkin.fromFirestore(doc.id, data);
    }
    return <CardSkin>[
      for (final b in kAvailableCardSkins)
        if (!hidden.contains(b.id)) _mergeSkin(overrides.remove(b.id), b),
      ...overrides.values,
    ];
  });
});

/// Merge a live Firestore skin over its bundled counterpart. The live doc wins
/// for price/name and a cloud cover image, BUT when the doc carries no image we
/// keep the bundled [assetPath] — so a skin whose art has been BAKED into the
/// app renders from the local bundle (instant, no cloud read) even while a live
/// doc still tunes its price. Bundled skins have no assetPath until baked, so
/// today this is a no-op and behaviour is unchanged.
CardSkin _mergeSkin(CardSkin? override, CardSkin bundled) {
  if (override == null) return bundled;
  if (override.coverImageUrl == null && bundled.assetPath != null) {
    return CardSkin(
      id: override.id,
      name: override.name,
      price: override.price,
      assetPath: bundled.assetPath,
      previewImageUrl: override.previewImageUrl,
    );
  }
  return override;
}

/// Merged skin list: Firestore skins when available, otherwise hardcoded fallback.
final allSkinsProvider = Provider<List<CardSkin>>((ref) {
  final firestoreSkins = ref.watch(firestoreSkinsProvider);
  return firestoreSkins.valueOrNull ?? kAvailableCardSkins;
});
