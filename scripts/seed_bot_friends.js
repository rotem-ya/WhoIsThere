// Seeds 7 fake "bot friend" users, attached ONLY to one real account's
// friends list, for testing the friends-game UI (leaderboard, groups,
// invite picker, chat) without needing real testers.
//
// One-sided by design: writes users/{botUid} + users/{targetUid}/friends/{botUid}.
// Does NOT write users/{botUid}/friends/{targetUid} — bots never sign in, so
// they never read their own friends list.
//
// Run via .github/workflows/seed-bot-friends.yml (workflow_dispatch,
// input: target_email). Safe to re-run — every write is a deterministic-id set().
const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
const targetEmail = process.env.TARGET_EMAIL;

if (!targetEmail) {
  console.error('Missing TARGET_EMAIL env var.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Same Israeli-name pool used for in-room bots (room_service.dart _botNames),
// so these feel consistent with the rest of the app.
const BOT_NAMES = ['אריאל', 'נועה', 'עמית', 'שירה', 'דניאל', 'מאיה', 'ליאור'];

async function main() {
  const user = await admin.auth().getUserByEmail(targetEmail);
  const targetUid = user.uid;
  console.log(`Resolved ${targetEmail} -> ${targetUid}`);

  const targetDoc = await db.collection('users').doc(targetUid).get();
  if (!targetDoc.exists) {
    console.error(`users/${targetUid} does not exist — sign into the app at least once first.`);
    process.exit(1);
  }

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  BOT_NAMES.forEach((name, i) => {
    const botUid = `bot_friend_${String(i + 1).padStart(2, '0')}`;
    const botRef = db.collection('users').doc(botUid);
    batch.set(botRef, {
      name,
      isTestBot: true,
      friendsGamePoints: (i + 1) * 15,
      totalPoints: (i + 1) * 40,
      discoveredImageIds: [],
      createdAt: now,
    }, { merge: true });

    const friendRef = db.collection('users').doc(targetUid).collection('friends').doc(botUid);
    batch.set(friendRef, { name, since: now });

    console.log(`  + ${botUid} (${name}) -> friend of ${targetUid}`);
  });

  await batch.commit();
  console.log(`Done. ${BOT_NAMES.length} bot friends attached to ${targetEmail} (${targetUid}).`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
