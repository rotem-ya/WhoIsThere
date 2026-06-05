// Deploys firestore.rules via the Firebase Rules REST API using the
// FIREBASE_SERVICE_ACCOUNT credentials. This avoids firebase-tools' Service
// Usage precheck (which needs serviceusage.services.get the SA doesn't have).
//
// Requires the service account to have firebaserules permissions
// (roles/firebaserules.admin, roles/firebase.admin, or Editor/Owner).

const fs = require('fs');
const { GoogleAuth } = require('google-auth-library');

const PROJECT = process.env.FIREBASE_PROJECT || 'whoisthere-380fa';
const RULES_FILE = process.env.RULES_FILE || 'firestore.rules';
const BASE = 'https://firebaserules.googleapis.com/v1';

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
      source: { files: [{ name: 'firestore.rules', content: source }] },
    }),
  });
  if (!createRes.ok) {
    throw new Error(`create ruleset failed: ${createRes.status} ${await createRes.text()}`);
  }
  const ruleset = await createRes.json();
  console.log('Created ruleset:', ruleset.name);

  // 2) Point the cloud.firestore release at the new ruleset.
  const releaseName = `projects/${PROJECT}/releases/cloud.firestore`;
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

  console.log(`Firestore rules deployed to ${PROJECT} (release cloud.firestore).`);
}

main().catch((e) => {
  console.error('Rules deploy failed:', e.message);
  process.exit(1);
});
