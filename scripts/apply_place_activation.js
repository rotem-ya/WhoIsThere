// Apply a place-activation patch to the local place catalogue, by id.
//
// This is the SAFE update point the admin app talks to. The admin app exports
// a small patch (a list of { id, is_active }); this tool merges it into
// assets/game_places/data/israel_places.json *by id*, in place, so that:
//   • places are NEVER deleted or reordered — only their is_active flag flips,
//   • the whole file is never blindly replaced (merge, not overwrite),
//   • the write is atomic (temp file + rename), so a crash can't corrupt data,
//   • every change is reversible (set is_active back to true),
//   • unknown ids in the patch are reported and skipped, never fatal.
//
// Usage:
//   node scripts/apply_place_activation.js <patch.json> [places.json]
//   node scripts/apply_place_activation.js <patch.json> --dry-run
//
// Defaults: places.json = assets/game_places/data/israel_places.json
//
// Patch format (see docs/admin/PLACE_ACTIVATION_CONTRACT.md):
//   {
//     "schema": "whoisthere.place-activation/v1",
//     "generated_at": "2026-06-12T12:00:00Z",
//     "updates": [
//       { "id": "masada",   "is_active": false },
//       { "id": "dead_sea", "is_active": true  }
//     ]
//   }

const fs = require('fs');
const path = require('path');

const DEFAULT_PLACES = 'assets/game_places/data/israel_places.json';
const SCHEMA = 'whoisthere.place-activation/v1';

function die(msg) {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}

function readJson(file) {
  let raw;
  try {
    raw = fs.readFileSync(file, 'utf8');
  } catch (e) {
    die(`cannot read ${file}: ${e.message}`);
  }
  try {
    return JSON.parse(raw);
  } catch (e) {
    die(`${file} is not valid JSON: ${e.message}`);
  }
}

// The catalogue may be a bare array or an object { "places": [...] }.
// Return { container, list } so we can write the same shape back out.
function extractPlaces(catalogue) {
  if (Array.isArray(catalogue)) return { container: catalogue, list: catalogue };
  if (catalogue && Array.isArray(catalogue.places)) {
    return { container: catalogue, list: catalogue.places };
  }
  die('places file has an unexpected shape (expected an array or { "places": [...] }).');
}

function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const positional = args.filter((a) => !a.startsWith('--'));
  const patchFile = positional[0];
  const placesFile = positional[1] || DEFAULT_PLACES;

  if (!patchFile) {
    die('usage: node scripts/apply_place_activation.js <patch.json> [places.json] [--dry-run]');
  }

  const patch = readJson(patchFile);
  if (patch.schema && patch.schema !== SCHEMA) {
    console.warn(`WARN: patch schema "${patch.schema}" != expected "${SCHEMA}" — continuing.`);
  }
  const updates = patch.updates;
  if (!Array.isArray(updates)) {
    die('patch.updates must be an array of { id, is_active }.');
  }

  const catalogue = readJson(placesFile);
  const { container, list } = extractPlaces(catalogue);
  const beforeCount = list.length;

  // Index places by id for an O(1) merge.
  const byId = new Map();
  for (const place of list) {
    if (place && typeof place.id === 'string') byId.set(place.id, place);
  }

  const unknown = [];
  let activated = 0;
  let hidden = 0;
  let unchanged = 0;

  for (const u of updates) {
    if (!u || typeof u.id !== 'string') {
      die(`every update needs a string "id" (offending entry: ${JSON.stringify(u)}).`);
    }
    if (typeof u.is_active !== 'boolean') {
      die(`update for "${u.id}" must have a boolean "is_active".`);
    }
    const place = byId.get(u.id);
    if (!place) {
      unknown.push(u.id);
      continue;
    }
    // Treat a missing field as the current "active" default when comparing.
    const current = place.is_active !== false;
    if (current === u.is_active) {
      unchanged++;
    } else if (u.is_active) {
      activated++;
    } else {
      hidden++;
    }
    place.is_active = u.is_active;
  }

  // Safety net: the merge must never drop or add places.
  const afterCount = list.length;
  if (afterCount !== beforeCount) {
    die(`place count changed (${beforeCount} -> ${afterCount}); refusing to write.`);
  }

  console.log(`Patch applied to ${placesFile}:`);
  console.log(`  places: ${beforeCount} (unchanged total — merge by id)`);
  console.log(`  activated: ${activated}, hidden: ${hidden}, no-op: ${unchanged}`);
  if (unknown.length) {
    console.warn(`  skipped ${unknown.length} unknown id(s): ${unknown.join(', ')}`);
  }

  if (dryRun) {
    console.log('  --dry-run: no file written.');
    return;
  }

  // Atomic write: serialize to a sibling temp file, then rename over the
  // target. rename() is atomic on the same filesystem, so readers never see a
  // half-written catalogue.
  const out = JSON.stringify(container, null, 2) + '\n';
  const dir = path.dirname(placesFile);
  const tmp = path.join(dir, `.${path.basename(placesFile)}.tmp-${process.pid}`);
  fs.writeFileSync(tmp, out, 'utf8');
  fs.renameSync(tmp, placesFile);
  console.log(`  written atomically.`);
}

main();
