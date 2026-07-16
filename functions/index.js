/**
 * WhoIsThere Cloud Functions — push notifications.
 *
 * Sends an FCM push when a friend invites you to a game (and when someone sends
 * you a friend request) so the notification arrives even if the app is closed.
 *
 * Data model (written by the Flutter client):
 *   users/{uid}.fcmTokens : string[]   device tokens (arrayUnion on each device)
 *   gameInvites/{toUid_fromUid} : { fromUid, fromName, toUid, roomId, code }
 *   friendRequests/{toUid_fromUid} : { fromUid, fromName, toUid, status }
 *   groupInvites/{toUid_groupId} : { fromUid, fromName, toUid, groupId, groupName }
 *
 * Deploy:  firebase deploy --only functions   (requires the Blaze plan)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/** Reads a user's device tokens (always an array). */
async function tokensFor(uid) {
  if (!uid) return [];
  const snap = await db.collection("users").doc(uid).get();
  const tokens = snap.exists ? snap.data().fcmTokens : null;
  return Array.isArray(tokens) ? tokens.filter((t) => !!t) : [];
}

/**
 * Sends [notification]+[data] to all of [uid]'s devices and prunes any tokens
 * FCM reports as unregistered/invalid so dead tokens don't pile up.
 */
async function pushToUser(uid, notification, data) {
  const tokens = await tokensFor(uid);
  if (tokens.length === 0) {
    functions.logger.info(`no tokens for ${uid} — skipping push`);
    return;
  }

  const res = await messaging.sendEachForMulticast({
    tokens,
    notification,
    data: data || {},
    android: { priority: "high", notification: { sound: "default" } },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  });

  // Prune tokens that are no longer valid.
  const stale = [];
  res.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token" ||
        code === "messaging/invalid-argument"
      ) {
        stale.push(tokens[i]);
      }
    }
  });
  if (stale.length > 0) {
    await db.collection("users").doc(uid).set(
      { fcmTokens: admin.firestore.FieldValue.arrayRemove(...stale) },
      { merge: true }
    );
    functions.logger.info(`pruned ${stale.length} stale token(s) for ${uid}`);
  }

  functions.logger.info(
    `push to ${uid}: ${res.successCount} ok, ${res.failureCount} failed`
  );
}

/**
 * Friend invited you to a game → "X מזמין אותך למשחק".
 *
 * Uses onWrite (not onCreate) because the client writes invites with a
 * deterministic id (`{toUid}_{fromUid}`); re-inviting the same friend to a new
 * room overwrites the doc instead of creating one. We push on the first create
 * and on any re-invite where the room/code actually changed.
 */
exports.onGameInvite = functions.firestore
  .document("gameInvites/{inviteId}")
  .onWrite(async (change) => {
    if (!change.after.exists) return; // deletion — nothing to push
    const inv = change.after.data() || {};
    const before = change.before.exists ? change.before.data() || {} : null;
    if (before) {
      // An update — only push if this is a genuinely new invitation.
      const sameRoom = before.roomId === inv.roomId && before.code === inv.code;
      if (sameRoom) return;
    }
    const toUid = inv.toUid;
    const fromName = inv.fromName || "חבר";
    if (!toUid) return;

    await pushToUser(
      toUid,
      {
        title: "הזמנה למשחק 🎮",
        body: `${fromName} מזמין אותך למשחק!`,
      },
      {
        type: "game_invite",
        roomId: inv.roomId || "",
        code: inv.code || "",
        fromUid: inv.fromUid || "",
      }
    );
  });

/** Someone sent you a friend request → "X שלח לך בקשת חברות". */
exports.onFriendRequest = functions.firestore
  .document("friendRequests/{requestId}")
  .onCreate(async (snap) => {
    const req = snap.data() || {};
    const toUid = req.toUid;
    const fromName = req.fromName || "מישהו";
    if (!toUid) return;

    await pushToUser(
      toUid,
      {
        title: "בקשת חברות 👋",
        body: `${fromName} רוצה להיות חבר שלך`,
      },
      {
        type: "friend_request",
        fromUid: req.fromUid || "",
      }
    );
  });

/**
 * Friend invited you to join their group → "X מזמין אותך לקבוצה".
 *
 * Same onWrite pattern as onGameInvite: the client writes with a deterministic
 * id (`{toUid}_{groupId}`), so re-inviting the same person to the same group
 * overwrites the doc instead of creating a new one — push only on a genuinely
 * new invite.
 */
exports.onGroupInvite = functions.firestore
  .document("groupInvites/{inviteId}")
  .onWrite(async (change) => {
    if (!change.after.exists) return; // deletion (declined/accepted) — no push
    if (change.before.exists) return; // re-write of the same pending invite
    const inv = change.after.data() || {};
    const toUid = inv.toUid;
    const fromName = inv.fromName || "חבר";
    const groupName = inv.groupName || "קבוצה";
    if (!toUid) return;

    await pushToUser(
      toUid,
      {
        title: "הזמנה לקבוצה 👥",
        body: `${fromName} מזמין אותך להצטרף לקבוצה "${groupName}"`,
      },
      {
        type: "group_invite",
        groupId: inv.groupId || "",
        fromUid: inv.fromUid || "",
      }
    );
  });
