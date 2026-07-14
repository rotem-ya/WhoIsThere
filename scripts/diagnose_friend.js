// Read-only diagnostic for a broken friendship: a friend appears in the
// cumulative leaderboard (users/{me}.friendsGamePoints-derived) but not in
// the friends list itself, even after a refresh. Both screens are SUPPOSED
// to read the exact same source (users/{me}/friends/{friendUid}), so this
// dumps the raw documents involved on both sides so the real state is known
// instead of guessed from screenshots.
//
// Usage:
//   FIREBASE_SERVICE_ACCOUNT='<service-account-json>' \
//     node scripts/diagnose_friend.js <myUid> <friendNameOrUid>
//
// <friendNameOrUid> can be the friend's exact uid, OR a display name — if a
// name is given, every user whose `name` field matches is checked (names
// aren't unique) and every friends/{...} subcollection doc whose id resolves
// to a user with that name is also checked, so a stale-uid friend entry
// still gets found even if the underlying user doc no longer has that name.
//
// Read-only — makes no writes. Once the actual asymmetry is known, fixing it
// is a one-line follow-up (delete the stale doc, or write the missing
// reciprocal one) — deliberately not automated here so a guess doesn't
// silently destroy real data.

const admin = require('firebase-admin');

function die(msg) {
  console.error(`ERROR: ${msg}`);
  process.exit(1);
}

async function main() {
  const [myUid, needle] = process.argv.slice(2);
  if (!myUid || !needle) {
    die('usage: node scripts/diagnose_friend.js <myUid> <friendNameOrUid>');
  }
  if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
    die('FIREBASE_SERVICE_ACCOUNT env var not set (service account JSON).');
  }

  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  const db = admin.firestore();

  console.log(`\n=== Me: ${myUid} ===`);
  const meDoc = await db.collection('users').doc(myUid).get();
  if (!meDoc.exists) {
    console.log('  ⚠️  users/{myUid} does not exist!');
  } else {
    const me = meDoc.data();
    console.log(`  name: ${me.name}`);
    console.log(`  friendsGamePoints: ${me.friendsGamePoints ?? 0}`);
  }

  console.log(`\n=== My friends subcollection (users/${myUid}/friends) ===`);
  const myFriendsSnap = await db
    .collection('users')
    .doc(myUid)
    .collection('friends')
    .get();
  if (myFriendsSnap.empty) {
    console.log('  (empty)');
  }
  const myFriendDocs = [];
  myFriendsSnap.forEach((d) => {
    const data = d.data();
    myFriendDocs.push({ uid: d.id, ...data });
    console.log(`  - ${d.id}  name="${data.name}"  since=${data.since?.toDate?.() ?? data.since}`);
  });

  // Resolve candidate uids: exact match on the subcollection id, plus a name
  // search across BOTH the subcollection docs' cached names and the live
  // users collection (covers a renamed or since-deleted account either way).
  const candidateUids = new Set();
  if (myFriendDocs.some((f) => f.uid === needle)) candidateUids.add(needle);
  for (const f of myFriendDocs) {
    if (f.name === needle) candidateUids.add(f.uid);
  }
  const usersByName = await db.collection('users').where('name', '==', needle).get();
  usersByName.forEach((d) => candidateUids.add(d.id));
  // Also treat the needle itself as a literal uid, in case it's not a name.
  candidateUids.add(needle);

  console.log(`\n=== Candidates matching "${needle}": ${candidateUids.size} ===`);
  for (const uid of candidateUids) {
    console.log(`\n--- Candidate uid: ${uid} ---`);
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      console.log('  users/{uid}: DOES NOT EXIST (deleted or never existed)');
    } else {
      const u = userDoc.data();
      console.log(`  users/{uid}: name="${u.name}" friendsGamePoints=${u.friendsGamePoints ?? 0}`);
    }

    const mineHasThem = await db
      .collection('users')
      .doc(myUid)
      .collection('friends')
      .doc(uid)
      .get();
    console.log(`  users/${myUid}/friends/${uid} (do I list them?): ${mineHasThem.exists ? 'EXISTS' : 'missing'}`);

    const theyHaveMe = await db
      .collection('users')
      .doc(uid)
      .collection('friends')
      .doc(myUid)
      .get();
    console.log(`  users/${uid}/friends/${myUid} (do they list me?): ${theyHaveMe.exists ? 'EXISTS' : 'missing'}`);

    if (mineHasThem.exists !== theyHaveMe.exists) {
      console.log('  ⚠️  ASYMMETRIC FRIENDSHIP — one side has the doc, the other doesn\'t.');
    }
  }

  console.log('\n=== Done (read-only, nothing written) ===\n');
}

main().catch((e) => die(e.stack || e.message));
