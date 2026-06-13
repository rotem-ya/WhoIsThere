# WhoIsThere — Admin Content Schema

> חוזה הנתונים בין **אפליקציית האדמין** (ניהול תוכן) לבין **אפליקציית המשחק**.
> כל מקום (place) חי כמסמך ב-Firestore + קובץ תמונה ב-Firebase Storage.
> פרויקט Firebase: `whoisthere-380fa`.

ה-doc הזה מתאר את הסכמה היציבה שאפליקציית האדמין צריכה לכתוב אליה. אפליקציית
המשחק נטענת מתוך אותה סכמה (קולקציית `images`) ומציגה מקומות חדשים **בלי
עדכון אפליקציה**.

---

## 1. הרשאות אדמין (custom claim)

כתיבה ל-`images` ול-`place_images/**` ב-Storage מותרת **רק** למשתמש Firebase Auth
שנושא את ה-custom claim:

```json
{ "admin": true }
```

זה נאכף בשני קבצי החוקים:
- `firestore.rules` → `match /images/{imageId}` → `allow write: if request.auth.token.admin == true`
- `storage.rules` → `match /place_images/{allPaths=**}` → `allow write: if request.auth.token.admin == true`

### איך מעניקים את ה-claim
פעם אחת, מול ה-service account (Admin SDK / Cloud Functions / סקריפט מקומי):

```js
const admin = require('firebase-admin');
admin.initializeApp(); // GOOGLE_APPLICATION_CREDENTIALS = FIREBASE_SERVICE_ACCOUNT
await admin.auth().setCustomUserClaims('<ADMIN_UID>', { admin: true });
// המשתמש חייב להתחבר מחדש / לרענן טוקן כדי שה-claim ייכנס לתוקף.
```

> אפליקציית האדמין נכנסת עם חשבון האדמין; אחרי `setCustomUserClaims` יש לבצע
> `user.getIdToken(true)` או התחברות מחדש כדי שה-token יישא את ה-claim.

---

## 2. Firestore — קולקציית `images`

מזהה המסמך (`imageId`) = ה-slug של המקום באנגלית, lowercase, מילים מופרדות ב-`_`
(לדוגמה `western_wall`, `dome_of_the_rock`). משמש גם כשם קובץ התמונה ב-Storage.

| שדה | טיפוס | חובה | תיאור |
|------|-------|------|-------|
| `name` | string | ✅ | שם המקום לתצוגה (עברית). למשל `"הכותל המערבי"` |
| `answer` | string | ✅ | התשובה הקנונית להשוואה (עברית). למשל `"הכותל"` |
| `acceptedAnswers` | string[] | — | כינויים/חלופות מקובלות (עברית). ברירת מחדל `[]` |
| `facts` | string[] | — | רמזים/עובדות (עברית), 2+ מומלץ. ברירת מחדל `[]` |
| `category` | string | ✅ | אחד מערכי ה-enum (ר׳ §4). למקומות בישראל: `israeliLandmark` |
| `city` | string | — | עיר/אזור (עברית). למשל `"ירושלים"` |
| `difficulty` | string | — | `easy` \| `medium` \| `hard`. ברירת מחדל `easy` |
| `isPremium` | bool | — | האם תוכן פרימיום. ברירת מחדל `false` |
| `cost` | number | — | מחיר במטבעות (אם פרימיום). ברירת מחדל `0` |
| `imageUrl` | string | ✅ | download URL של התמונה המלאה מ-Storage |
| `thumbnailUrl` | string | — | download URL של תמונה ממוזערת. אם חסר — השתמש ב-`imageUrl` |
| `storagePath` | string | ✅ | נתיב Storage של התמונה המלאה (לעדכון/מחיקה). למשל `place_images/western_wall.jpg` |
| `thumbnailStoragePath` | string | — | נתיב Storage של הממוזערת |
| `isActive` | bool | ✅ | רק `true` מוצג במשחק. כיבוי מקום = `false` (לא למחוק) |
| `createdAt` | timestamp | ✅ | `FieldValue.serverTimestamp()` בעת יצירה |
| `updatedAt` | timestamp | ✅ | `FieldValue.serverTimestamp()` בכל עדכון |

### דוגמת מסמך — `images/western_wall`
```json
{
  "name": "הכותל המערבי",
  "answer": "הכותל",
  "acceptedAnswers": ["הכותל המערבי", "הכותל"],
  "facts": [
    "אבן עתיקה שמחזיקה זיכרונות של אלפי שנים",
    "מגיעים אליו ממרחקים רבים עם מילים שמבקשים לשמור"
  ],
  "category": "israeliLandmark",
  "city": "ירושלים",
  "difficulty": "easy",
  "isPremium": false,
  "cost": 0,
  "imageUrl": "https://firebasestorage.googleapis.com/v0/b/whoisthere-380fa.appspot.com/o/place_images%2Fwestern_wall.jpg?alt=media&token=...",
  "thumbnailUrl": "https://firebasestorage.googleapis.com/v0/b/whoisthere-380fa.appspot.com/o/place_images%2Fthumbs%2Fwestern_wall.jpg?alt=media&token=...",
  "storagePath": "place_images/western_wall.jpg",
  "thumbnailStoragePath": "place_images/thumbs/western_wall.jpg",
  "isActive": true,
  "createdAt": "<serverTimestamp>",
  "updatedAt": "<serverTimestamp>"
}
```

---

## 3. Firebase Storage — מבנה התיקיות

```
place_images/<imageId>.<ext>          # התמונה המלאה (jpg/png/webp)
place_images/thumbs/<imageId>.<ext>   # ממוזערת (אופציונלי)
```

- מגבלות חוקים: ≤ 10MB, `contentType` חייב להתחיל ב-`image/`.
- מומלץ: דחיסה ל-JPG ברוחב ~1080px לתמונה המלאה, ~400px לממוזערת.
- שם הקובץ = `imageId` (אותו slug כמו מזהה מסמך Firestore).

---

## 4. ערכי `category` החוקיים

מתוך `lib/core/constants/game_constants.dart` (`enum ImageCategory`). יש לכתוב
את שם הערך **בדיוק** (case-sensitive):

`singer` · `actor` · `athlete` · `politician` · `place` · `landmark` · `israeliLandmark`

> למקומות בישראל השתמש ב-`israeliLandmark`. ערך לא מוכר → המשחק נופל ל-`place`.

---

## 5. זרימת עבודה לאפליקציית האדמין (הוספת מקום)

1. המשתמש בוחר תמונה + ממלא שדות (name, answer, facts, city, difficulty…).
2. גזירת `imageId` מ-slug אנגלי.
3. העלאת התמונה ל-`place_images/<imageId>.jpg` (ואופציונלית הממוזערת ל-`thumbs/`).
4. קבלת `getDownloadURL()` לכל קובץ.
5. כתיבת מסמך `images/<imageId>` עם כל השדות מ-§2 (כולל `storagePath`,
   `imageUrl`, `serverTimestamp` ל-`createdAt`/`updatedAt`, `isActive: true`).
6. עריכה = `set(..., merge:true)` + עדכון `updatedAt`. כיבוי = `isActive:false`.
   מחיקה מלאה = מחיקת מסמך Firestore **וגם** קבצי ה-Storage (`storagePath`,
   `thumbnailStoragePath`).

---

## 6. צד אפליקציית המשחק (לעיון)

- המשחק קורא את הקטלוג מקולקציית `images` (read לכל משתמש מחובר) ומסנן
  `isActive == true`.
- `GameImageModel.fromFirestore` (`lib/models/game_image_model.dart`) ממפה את
  המסמך. כיום הוא קורא: `name, answer, acceptedAnswers, category, isPremium,
  cost, imageUrl, thumbnailUrl`. בפאזה הבאה יורחב לקרוא גם `facts` ו-`isActive`.
- תמונות נטענות עם `cached_network_image` מ-`imageUrl`.
- היום המקומות נטענים מ-assets מקומיים (`assets/game_places/data/israel_places.json`
  + whitelist קשיח `_availableLocalPlaceIds` ב-`room_service.dart`). בפאזה הבאה
  הטעינה תעבור/תתמזג מול Firestore כך שתוכן אדמין יופיע בלי עדכון אפליקציה.

---

## 7. פריסת חוקי האבטחה

- `firestore.rules` → workflow `deploy-firestore-rules.yml` (אוטומטי ב-push ל-main
  שמשנה את הקובץ, או ידני).
- `storage.rules` → workflow `deploy-storage-rules.yml` (אותו מנגנון).
  ⚠️ אם ה-bucket אינו `whoisthere-380fa.appspot.com` (פרויקטים חדשים: `.firebasestorage.app`)
  יש להגדיר Actions variable בשם `STORAGE_BUCKET` עם השם הנכון.
- שניהם משתמשים ב-secret הקיים `FIREBASE_SERVICE_ACCOUNT`.
