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
    // Keep ALL skins in the list, including ones the admin set active:false.
    // The store screen filters inactive out of the BUY grid, but the game must
    // still resolve an inactive skin so a player who already owns it keeps it.
    final overrides = <String, CardSkin>{};
    for (final doc in snap.docs) {
      overrides[doc.id] = CardSkin.fromFirestore(doc.id, doc.data());
    }
    return <CardSkin>[
      for (final b in kAvailableCardSkins) _mergeSkin(overrides.remove(b.id), b),
      ...overrides.values,
    ];
  });
});

/// Merge a live Firestore skin over its bundled counterpart. Built-in covers
/// render from CODE (VaultCover's Candy jelly, keyed by id), so an admin doc for
/// a bundled id may adjust name/price only — never a cover image and never
/// hiding it: we drop coverImageUrl/previewImageUrl and force active. Brand-new
/// admin ids (not bundled) are appended untouched, so admin skins are ADDED as
/// images alongside the built-ins, never replacing them.
CardSkin _mergeSkin(CardSkin? override, CardSkin bundled) {
  if (override == null) return bundled;
  return CardSkin(
    id: bundled.id,
    name: override.name,
    price: override.price,
    active: true,
  );
}

/// Merged skin list: Firestore skins when available, otherwise hardcoded fallback.
final allSkinsProvider = Provider<List<CardSkin>>((ref) {
  final firestoreSkins = ref.watch(firestoreSkinsProvider);
  return firestoreSkins.valueOrNull ?? kAvailableCardSkins;
});
