// Repairs a specific friendship asymmetry found by diagnose_friend.js.
// Deliberately requires an explicit action + both exact uids — it never
// guesses which side is "correct", so run diagnose_friend.js first and pick
// the action that matches what it printed.
//
// Usage:
//   FIREBASE_SERVICE_ACCOUNT='<service-account-json>' \
//     node scripts/fix_friendship.js <action> <ownerUid> <friendUid> [--dry-run]
//
// Actions:
//   add-missing    Write users/{ownerUid}/friends/{friendUid}, copying the
//                   friend's live `name` from users/{friendUid}. Use when
//                   diagnose_friend.js showed the doc missing on ownerUid's
//                   side but present on friendUid's side (or you've
//                   otherwise confirmed they should be friends).
//   remove-stale   Delete users/{ownerUid}/friends/{friendUid}. Use for an
//                   orphaned entry (e.g. friendUid's account no longer
//                   exists, or the friendship should not exist).
//
// Only ever touches ONE side (users/{ownerUid}/friends/{friendUid}) per run —
// run it twice (swapping owner/friend) to fix both sides of an asymmetry.

const admin = require('firebase-admin');

function die(msg) {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const positional = args.filter((a) => !a.startsWith('--'));
  const [action, ownerUid, friendUid] = positional;

  if (!['add-missing', 'remove-stale'].includes(action) || !ownerUid || !friendUid) {
    die(
      'usage: node scripts/fix_friendship.js <add-missing|remove-stale> <ownerUid> <friendUid> [--dry-run]'
    );
  }
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
    die('FIREBASE_SERVICE_ACCOUNT env var not set (service account JSON).');
  }

  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  const ref = db.collection('users').doc(ownerUid).collection('friends').doc(friendUid);
  const existing = await ref.get();

  if (action === 'add-missing') {
    if (existing.exists) {
      console.log(`users/${ownerUid}/friends/${friendUid} already exists — nothing to do.`);
      return;
    }
    const friendUserDoc = await db.collection('users').doc(friendUid).get();
    if (!friendUserDoc.exists) {
      die(`users/${friendUid} does not exist — can't copy a name for it. Aborting.`);
    }
    const friendName = friendUserDoc.data().name || 'שחקן';
    console.log(
      `${dryRun ? '[dry-run] would write' : 'Writing'} users/${ownerUid}/friends/${friendUid} = {name: "${friendName}", since: now}`
    );
    if (!dryRun) {
      await ref.set({ name: friendName, since: admin.firestore.FieldValue.serverTimestamp() });
      console.log('Done.');
    }
    return;
  }

  // remove-stale
  if (!existing.exists) {
    console.log(`users/${ownerUid}/friends/${friendUid} doesn't exist — nothing to do.`);
    return;
  }
  console.log(
    `${dryRun ? '[dry-run] would delete' : 'Deleting'} users/${ownerUid}/friends/${friendUid} (currently: ${JSON.stringify(existing.data())})`
  );
  if (!dryRun) {
    await ref.delete();
    console.log('Done.');
  }
}

main().catch((e) => die(e.stack || e.message));
