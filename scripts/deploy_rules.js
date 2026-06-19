// Deploys security rules via the Firebase Rules REST API using the
// FIREBASE_SERVICE_ACCOUNT credentials. This avoids firebase-tools' Service
// Usage precheck (which needs serviceusage.services.get the SA doesn't have).
//
// Requires the service account to have firebaserules permissions
// (roles/firebaserules.admin, roles/firebase.admin, or Editor/Owner).
//
// Target is selected via RULES_TARGET (default "firestore"):
//   RULES_TARGET=firestore  → release cloud.firestore,             file firestore.rules
//   RULES_TARGET=storage    → release firebase.storage/<bucket>,   file storage.rules
//
// Overridable env: FIREBASE_PROJECT, RULES_FILE, STORAGE_BUCKET.

const fs = require('fs');
const { GoogleAuth } = require('google-auth-library');

const PROJECT = process.env.FIREBASE_PROJECT || 'whoisthere-380fa';
const TARGET = process.env.RULES_TARGET || 'firestore';
const BASE = 'https://firebaserules.googleapis.com/v1';

// Per-target defaults: which local file, the ruleset entry name, and the
// release id the rules are published to.
const STORAGE_BUCKET = process.env.STORAGE_BUCKET || `${PROJECT}.appspot.com`;
const TARGETS = {
  firestore: { file: 'firestore.rules', entry: 'firestore.rules', release: 'cloud.firestore' },
  storage: { file: 'storage.rules', entry: 'storage.rules', release: `firebase.storage/${STORAGE_BUCKET}` },
};

const cfg = TARGETS[TARGET];
if (!cfg) {
  console.error(`Unknown RULES_TARGET "${TARGET}" (expected firestore|storage)`);
  process.exit(1);
}
const RULES_FILE = process.env.RULES_FILE || cfg.file;

async function main() {
  const source = fs.readFileSync(RULES_FILE, 'utf8');

  const auth = new GoogleAuth({
    scopes: [
      'https://www.googleapis.com/auth/firebase',
      'https://www.googleapis.com/auth/cloud-platform',
    ],
  });
  const client = await auth.getClient();
  const token = (await client.getAccessToken()).token;
  const headers = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };

  // 1) Create a new ruleset from the local rules file.
  const createRes = await fetch(`${BASE}/projects/${PROJECT}/rulesets`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      source: { files: [{ name: cfg.entry, content: source }] },
    }),
  });
  if (!createRes.ok) {
    throw new Error(`create ruleset failed: ${createRes.status} ${await createRes.text()}`);
  }
  const ruleset = await createRes.json();
  console.log('Created ruleset:', ruleset.name);

  // 2) Point the target release at the new ruleset.
  const releaseName = `projects/${PROJECT}/releases/${cfg.release}`;
  const patchRes = await fetch(`${BASE}/${releaseName}`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({
      release: { name: releaseName, rulesetName: ruleset.name },
    }),
  });

  if (patchRes.status === 404) {
    // No release yet — create it.
    const createRel = await fetch(`${BASE}/projects/${PROJECT}/releases`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ name: releaseName, rulesetName: ruleset.name }),
    });
    if (!createRel.ok) {
      throw new Error(`create release failed: ${createRel.status} ${await createRel.text()}`);
    }
  } else if (!patchRes.ok) {
    throw new Error(`update release failed: ${patchRes.status} ${await patchRes.text()}`);
  }

  console.log(`${TARGET} rules deployed to ${PROJECT} (release ${cfg.release}).`);
}

main().catch((e) => {
  console.error('Rules deploy failed:', e.message);
  process.exit(1);
});
