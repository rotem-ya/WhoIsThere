// Strips image overrides that fight the new code-rendered "Candy" skins
// (board_skin_background.dart gradients / vault_cover.dart jelly tiles).
//
// Since assetPath was removed from every built-in kBoardSkins/kAvailableCardSkins
// entry (see lib/models/board_skin.dart, lib/models/card_skin.dart on the
// visual-redesign branch), skin_providers.dart's _mergeSkin() and
// cosmetics_catalog_service.dart no longer have a baked local asset to prefer —
// any admin-published imageUrl/coverImageUrl now WINS over the code design,
// which is exactly the bug this fixes.
//
// Surgical, not destructive: strips only the image fields + assetPath, restores
// active:true, and PRESERVES any admin-set name/price customization — does not
// delete the boardSkins array or the card_skins collection docs outright.
//
// Run via .github/workflows/clean-cosmetics-images.yml (workflow_dispatch).
const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const BUILT_IN_BOARD_IDS = [
  'none', 'midnight', 'deep_sea', 'plum', 'forest', 'ember',
  'aurora', 'sunset', 'galaxy', 'royal_gold', 'nebula', 'emerald_dream',
];
const BUILT_IN_CARD_IDS = [
  'default', 'minimal_lines', 'minimal_calm',
  'nature_leaves', 'nature_waves', 'nature_anemone',
  'mosaic_arabesque', 'mosaic_tiles', 'mosaic_star',
  'neon_grid', 'neon_wave', 'neon_cyber',
  'cosmic_galaxy', 'cosmic_aurora', 'cosmic_fireice',
  'royal_magen',
];

async function cleanBoardSkins() {
  const ref = db.collection('cosmetics_catalog').doc('catalog_v1');
  const snap = await ref.get();
  if (!snap.exists) {
    console.log('cosmetics_catalog/catalog_v1 does not exist — nothing to clean.');
    return;
  }
  const data = snap.data();
  const boardSkins = Array.isArray(data.boardSkins) ? data.boardSkins : [];
  if (boardSkins.length === 0) {
    console.log('boardSkins array is empty — nothing to clean.');
    return;
  }

  let changed = 0;
  const cleaned = boardSkins.map((entry) => {
    if (!entry || !BUILT_IN_BOARD_IDS.includes(entry.id)) return entry;
    const { imageUrl, assetPath, ...rest } = entry;
    if (imageUrl === undefined && assetPath === undefined && rest.active === true) {
      return entry; // already clean
    }
    changed++;
    return { ...rest, active: true };
  });

  await ref.set({ boardSkins: cleaned }, { merge: true });
  console.log(`boardSkins: cleaned ${changed}/${boardSkins.length} entries (imageUrl/assetPath stripped, active:true restored).`);
}

async function cleanCardSkins() {
  const snap = await db.collection('card_skins').get();
  if (snap.empty) {
    console.log('card_skins collection is empty — nothing to clean.');
    return;
  }

  const batch = db.batch();
  let changed = 0;
  snap.docs.forEach((doc) => {
    if (!BUILT_IN_CARD_IDS.includes(doc.id)) return;
    const data = doc.data();
    if (data.coverImageUrl === undefined && data.previewImageUrl === undefined && data.active !== false) {
      return; // already clean
    }
    changed++;
    batch.set(doc.ref, {
      coverImageUrl: admin.firestore.FieldValue.delete(),
      previewImageUrl: admin.firestore.FieldValue.delete(),
      active: true,
    }, { merge: true });
  });

  if (changed === 0) {
    console.log('card_skins: nothing to clean.');
    return;
  }
  await batch.commit();
  console.log(`card_skins: cleaned ${changed}/${snap.docs.length} built-in docs (coverImageUrl/previewImageUrl removed, active:true restored).`);
}

async function main() {
  await cleanBoardSkins();
  await cleanCardSkins();
  console.log('Done. Board skins render as code gradients, card skins render as code jelly tiles.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
