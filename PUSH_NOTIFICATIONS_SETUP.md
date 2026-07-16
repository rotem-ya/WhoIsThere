# הודעות פוש (הזמנות חברים/משחק/קבוצה) — מדריך הקמה (לcowork / קלוד אדמין)

המטרה: כשחבר מזמין אותך למשחק, שולח בקשת חברות, או מזמין אותך לקבוצה, תגיע
**הודעת פוש למכשיר גם כשהאפליקציה סגורה**. הצד של הקוד באפליקציה כבר מוכן (ראה
"מה כבר נעשה בקוד" למטה). מה שנותר הם צעדים בקונסולות שאני (Claude של הריפו) לא
יכול לבצע — הם מפורטים כאן צעד-אחר-צעד.

⚠️ **סטטוס נכון ל-2026-07-11: לא ברור אם הצעדים למטה כבר בוצעו.** אם אתה לא
זוכר שביצעת אותם, כנראה שלא — תתחיל מסעיף 1. איך לבדוק בלי לנחש: Firebase
Console → **Functions**. אם אתה רואה שם `onGameInvite`/`onFriendRequest`/
`onGroupInvite` בסטטוס פעיל — הפריסה כבר בוצעה, קפוץ ישר לסעיף 4 (יש פונקציה
חדשה, `onGroupInvite`, שנוספה בסשן הזה וטרם נפרסה גם אם השאר כבר רץ).

---

## מה כבר נעשה בקוד (בריפו, בענף ההשקה הנוכחי)
- נוסף `firebase_messaging` ל-`pubspec.yaml`.
- `lib/services/notification_service.dart` — בקשת הרשאה, שמירת ה-FCM token תחת
  `users/{uid}.fcmTokens` (arrayUnion, תומך כמה מכשירים), רענון token, וניווט
  ל-`/friends` בלחיצה על ההודעה.
- `lib/main.dart` — רישום background handler, init של השירות, ורישום token לכל
  משתמש מחובר. הכל fail-soft (לא חוסם הפעלה).
- `functions/` — שלוש Cloud Functions ששולחות FCM כשנוצרת הזמנה/בקשה:
  `onGameInvite` (הזמנת משחק), `onFriendRequest` (בקשת חברות), `onGroupInvite`
  (הזמנה להצטרף לקבוצה קבועה — חדש).
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
מתבצע ממחשב עם Firebase CLI מחובר לפרויקט (רותם/אדמין). לא צריך ענף מיוחד —
פשוט הענף העדכני ביותר של הריפו (`claude/whothere-v111-launch-iqkbq2` נכון
לרגע זה; אפשר גם `main`):
```bash
git fetch origin claude/whothere-v111-launch-iqkbq2
git checkout claude/whothere-v111-launch-iqkbq2
cd functions
npm install
cd ..
firebase deploy --only functions
```
זה גם מה שצריך להריץ כדי לפרוס את `onGroupInvite` החדשה, גם אם `onGameInvite`
ו-`onFriendRequest` כבר רצות (הפקודה פורסת מחדש את כל הפונקציות בקובץ, לא
מזיקה לקיימות).

אחרי הפריסה יופיעו ב-Firebase Console → **Functions** שלוש פונקציות:
`onGameInvite`, `onFriendRequest`, `onGroupInvite`.

---

## בדיקה (אחרי כל הצעדים)
1. התקן את ה-build החדש על **שני** מכשירים/חשבונות שהם חברים.
2. במכשיר A: צור משחק עם חברים והזמן את B מרשימת החברים (כפתור 🎮 / פלוס בסלוט),
   או צור קבוצה עם B, או שלח לו בקשת חברות.
3. סגור לגמרי את האפליקציה במכשיר B.
4. צריכה להופיע הודעת פוש (למשל "הזמנה למשחק 🎮 — A מזמין אותך למשחק!" או
   "הזמנה לקבוצה 👥").
5. לחיצה על ההודעה פותחת את האפליקציה במסך החברים עם הבאנר המתאים.

### אם פוש לא מגיע
- בדוק ב-Firebase Console → Functions → Logs שהפונקציה הרלוונטית רצה ולא נכשלה.
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
