# הודעות פוש להזמנות חברים — מדריך הקמה (לcowork / קלוד אדמין)

המטרה: כשחבר מזמין אותך למשחק (או שולח בקשת חברות), תגיע **הודעת פוש למכשיר גם
כשהאפליקציה סגורה**. הצד של הקוד באפליקציה כבר מוכן (ראה "מה כבר נעשה בקוד"
למטה). מה שנותר הם צעדים בקונסולות שאני (Claude של הריפו) לא יכול לבצע — הם
מפורטים כאן צעד-אחר-צעד.

---

## מה כבר נעשה בקוד (בריפו, בענף `claude/push-invites`)
- נוסף `firebase_messaging` ל-`pubspec.yaml`.
- `lib/services/notification_service.dart` — בקשת הרשאה, שמירת ה-FCM token תחת
  `users/{uid}.fcmTokens` (arrayUnion, תומך כמה מכשירים), רענון token, וניווט
  ל-`/friends` בלחיצה על ההודעה.
- `lib/main.dart` — רישום background handler, init של השירות, ורישום token לכל
  משתמש מחובר. הכל fail-soft (לא חוסם הפעלה).
- `functions/` — Cloud Function (`onGameInvite`, `onFriendRequest`) ששולחת FCM
  למקבל כשנוצרת הזמנה/בקשה.
- iOS: `aps-environment = production` נוסף ל-`Runner.entitlements`.

---

## צעדי הקמה — Firebase / Google (קלוד אדמין או רותם)

### 1. שדרוג לתוכנית Blaze (חובה ל-Cloud Functions)
Cloud Functions לא רצות בתוכנית Spark החינמית.
- Firebase Console → הפרויקט → ⚙️ → **Usage and billing** → **Modify plan** →
  בחר **Blaze (Pay as you go)**.
- בפועל העלות אפסית בנפח כזה (יש מכסה חינמית נדיבה), אבל נדרש חיבור כרטיס אשראי.

### 2. הפעלת Cloud Messaging API
- Firebase Console → ⚙️ → **Project settings** → **Cloud Messaging**.
- ודא ש-**Firebase Cloud Messaging API (V1)** מופעל (Enabled). אם לא — לחץ Enable
  (זה פותח את Google Cloud Console ומפעיל את ה-API).

### 3. iOS בלבד — מפתח APNs (חובה כדי שפוש יעבוד באייפון)
בלי זה, פוש יעבוד באנדרואיד אבל **לא** באייפון.
- Apple Developer → **Certificates, Identifiers & Profiles** → **Keys** → **+** →
  סמן **Apple Push Notifications service (APNs)** → צור והורד את קובץ ה-`.p8`.
  שמור את ה-**Key ID** ואת ה-**Team ID**.
- Firebase Console → ⚙️ → **Project settings** → **Cloud Messaging** → תחת
  **Apple app configuration** → **APNs Authentication Key** → **Upload** →
  העלה את ה-`.p8` + הזן Key ID + Team ID.
- ודא ש-Capability של **Push Notifications** מופעל ב-App ID של
  `com.rotem.whoisthere` (Apple Developer → Identifiers → האפליקציה →
  Push Notifications ✓). הפרופיל ב-Codemagic מתחדש אוטומטית.

### 4. פריסת ה-Cloud Functions
מתבצע ממחשב עם Firebase CLI מחובר לפרויקט (רותם/אדמין):
```bash
git fetch origin claude/push-invites
git checkout claude/push-invites
cd functions
npm install
cd ..
firebase deploy --only functions
```
אחרי הפריסה יופיעו ב-Firebase Console → **Functions** שתי פונקציות:
`onGameInvite`, `onFriendRequest`.

---

## בדיקה (אחרי כל הצעדים)
1. התקן את ה-build החדש (מהענף הזה) על **שני** מכשירים/חשבונות שהם חברים.
2. במכשיר A: צור משחק עם חברים והזמן את B מרשימת החברים (כפתור 🎮 / פלוס בסלוט).
3. סגור לגמרי את האפליקציה במכשיר B.
4. צריכה להופיע הודעת פוש "הזמנה למשחק 🎮 — A מזמין אותך למשחק!".
5. לחיצה על ההודעה פותחת את האפליקציה במסך החברים עם באנר ההזמנה.

### אם פוש לא מגיע
- בדוק ב-Firebase Console → Functions → Logs שה-`onGameInvite` רצה ולא נכשלה.
- ודא ש-`users/{uid}.fcmTokens` של המקבל מכיל token (Firestore Console).
- אייפון: כמעט תמיד חוסר מפתח APNs (צעד 3) או Capability לא מופעל.
- אנדרואיד: ודא ש-`google-services.json` בפרויקט תואם לחבילה `com.whoisthere.app`.

---

## הערות
- הרשאת ההתראות נדרשת מהמשתמש (Android 13+ / iOS). השירות מבקש אותה בהפעלה
  הראשונה; אם המשתמש מסרב — פשוט לא יקבל פוש, שאר האפליקציה לא מושפעת.
- הבאנר בתוך האפליקציה (gameInvitesProvider) ממשיך לעבוד כרגיל גם בלי פוש —
  הפוש הוא רובד נוסף למצב "אפליקציה סגורה".
- חוקי Firestore כבר מתירים למשתמש לכתוב את ה-doc של עצמו (כולל `fcmTokens`);
  ה-Function משתמשת ב-Admin SDK ועוקפת חוקים.
