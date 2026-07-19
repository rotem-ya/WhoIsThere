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
    // Built-in skins are code-authoritative: name, price, and the Candy jelly
    // rendering all come from kAvailableCardSkins, so an admin doc can NEVER
    // rename / reprice / re-image / hide a built-in id (that was causing
    // name-vs-art mismatches). Admin docs with a NEW id are appended as extra
    // cloud skins — added alongside the built-ins, never replacing them.
    final bundledIds = {for (final b in kAvailableCardSkins) b.id};
    final extras = <CardSkin>[];
    for (final doc in snap.docs) {
      if (bundledIds.contains(doc.id)) continue; // ignore overrides of built-ins
      extras.add(CardSkin.fromFirestore(doc.id, doc.data()));
    }
    return <CardSkin>[...kAvailableCardSkins, ...extras];
  });
});

/// Merged skin list: Firestore skins when available, otherwise hardcoded fallback.
final allSkinsProvider = Provider<List<CardSkin>>((ref) {
  final firestoreSkins = ref.watch(firestoreSkinsProvider);
  return firestoreSkins.valueOrNull ?? kAvailableCardSkins;
});
