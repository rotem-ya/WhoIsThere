# פרומפט ל-cowork — השלמת "פרסום חי" (Firebase Storage) + אימות מקצה-לקצה

> העתק את כל הטקסט הזה לסשן cowork במחשב. עבוד **שלב-שלב**: בכל פעולה שדורשת קליק אנושי (קונסול Firebase / אפליקציית האדמין) — בקש מרותם לבצע, המתן לאישור/צילום, ורק אז המשך.

## רקע — מה כבר ידוע ומה כבר נעשה (אל תחזור על זה)

- **הבעיה המקורית:** באפליקציית האדמין (https://rotem-ya.github.io/Guess_The_Place_Admin) כפתור "🔄 ייבא תמונות ששינית ב-🎲 ופרסם" (פרסום חי ל-Firebase Storage) נתקע 20 שניות לכל תמונה ונכשל (`timeout 20000ms`).
- **אבחנה סופית (2026-07-06):** ה-bucket ‏`whoisthere-380fa.firebasestorage.app` **מעולם לא נוצר** — Storage לא הופעל בפרויקט. זו הסיבה, לא CORS.
- **מה כבר בוצע:**
  1. רותם התחיל יצירת default bucket בקונסול Firebase (production mode). ייתכן שסיים — **לוודא, לא להניח**.
  2. חוקי Storage נפרסו אוטומטית מהריפו (`storage.rules` → workflow `deploy-storage-rules.yml`, רץ ירוק ב-2026-07-06). כתיבה: אדמין בלבד (claim `admin:true` או המייל `rot4735@gmail.com`), עד 10MB, תמונות בלבד, נתיב `place_images/**`.
  3. תוקן CORS ל-**Hosting** (זה נפרד!): `firebase.json` מגיש עכשיו `Access-Control-Allow-Origin: *` על `/assets/**` ו-`/content/**` — זה תיקן "Failed to fetch" במסך "👁️ תוכן המשחק" באדמין.
  4. ב-Cloud Shell של רותם קיים `cors.json` מוכן (origin: `https://rotem-ya.github.io`). ההחלה על ה-bucket נכשלה עם 404 כל עוד ה-bucket לא קיים.
- **חשבונות:** הפרויקט `whoisthere-380fa` שייך ל-`askthekids_app@...` (owner) ו/או `rot4735@gmail.com`. **ההתחברות באדמין חייבת להיות `rot4735@gmail.com`** (רק לו הרשאת כתיבה לפי rules). ב-Cloud Shell רותם כבר מחובר עם החשבון הנכון והפרויקט מקובע.

## המשימה — לפי הסדר

### שלב 1: לוודא שה-bucket קיים
בקש מרותם לפתוח https://console.firebase.google.com → פרויקט whoisthere-380fa → Build → Storage.
- אם רואים סייר קבצים (גם ריק) — ה-bucket קיים, המשך.
- אם עדיין מוצג אשף "Set up default bucket" — הנחה אותו: production mode → Create. אם נדרש שדרוג ל-**Blaze** — לאשר (pay-as-you-go; בהיקפים של המשחק העלות זניחה, וזה ממילא נדרש בעתיד לפוש הזמנות).

### שלב 2: להחיל CORS על ה-bucket (Cloud Shell)
בקש מרותם לפתוח https://shell.cloud.google.com (החשבון עם הפרויקט whoisthere-380fa) ולהריץ:
```bash
gsutil cors set cors.json gs://whoisthere-380fa.firebasestorage.app
gsutil cors get gs://whoisthere-380fa.firebasestorage.app
```
- הצלחה = השורה השנייה מדפיסה JSON עם `rotem-ya.github.io`.
- אם `cors.json` לא קיים (בית חדש), ליצור קודם:
```bash
cat > cors.json <<'EOF'
[
  {
    "origin": ["https://rotem-ya.github.io"],
    "method": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "responseHeader": ["Content-Type", "Authorization", "x-goog-resumable", "X-Firebase-Storage-Version", "X-Firebase-GMPID"],
    "maxAgeSeconds": 3600
  }
]
EOF
```
- אם עדיין `BucketNotFoundException` — חזור לשלב 1 (ה-bucket לא נוצר), או הרץ `gcloud storage buckets list --format="value(name)"` וראה אם שם ה-bucket שונה (למשל `whoisthere-380fa.appspot.com`). אם השם שונה — עצור ודווח; צריך לעדכן קונפיגורציה בשני הריפו.

### שלב 3: המבחן — פרסום חי מהאדמין
בקש מרותם (בטלפון או במחשב):
1. לפתוח את האדמין https://rotem-ya.github.io/Guess_The_Place_Admin — לוודא גרסה **v113** בתחתית, ולהתחבר עם **rot4735@gmail.com**.
2. בתפריט הצד: **"📡 ניהול תוכן"** (לא "👁️ תוכן המשחק").
3. ללחוץ **"🔄 ייבא תמונות ששינית ב-🎲 ופרסם"** ולאשר.
- הצלחה = ההעלאות רצות תוך שניות ("מעלה 1/93 … ✓"). לתת לזה לרוץ עד הסוף (93 תמונות, ~12MB).
- כישלון = עדיין timeout. במקרה כזה: לבקש דוח אבחון מהאדמין (⚙️ → דוח), לקרוא את השגיאה המדויקת. חשד משני מתועד: גרסת Firebase Web SDK באדמין (10.12.2) מול bucket מסוג `.firebasestorage.app` — במקרה כזה לשדרג את גרסת ה-SDK בקבצי האדמין (`assets/js/live.js` / reference) ולבדוק שוב. אין לשנות rules — הם נכונים ופרוסים.

### שלב 4: אחרי הצלחה — סגירת תיעוד (חובה)
1. בריפו האדמין `rotem-ya/Guess_The_Place_Admin`:
   - `handoff/FOR_GAME_CLAUDE.md` §2 — לסמן ✅ נפתר (הסיבה: bucket לא היה קיים; נוצר + CORS + rules פרוסים).
   - להסיר/לעדכן את הערת ה-fallback בסוף `assets/js/views/content.js` (ההודעה על "ההעלאות נתקעות") — אפשר להשאיר כ-fallback גנרי, רק לוודא שלא מטעה.
2. בריפו המשחק `rotem-ya/WhoIsThere` (ענף `claude/qa-launch-prep-EXqLn`): לעדכן ב-`CLAUDE.md` שהפרסום החי עובד (לחפש את האזכורים של "שבור"/"נתקע" בהקשר Storage).
3. **חשוב — אזהרת עלות/כפילות:** עכשיו כשהפרסום החי עובד, המניפסט החי יגיש override-ים לתמונות ש**כבר מוטמעות** ב-v1.1.1. אחרי ש-v1.1.1 באוויר יש לנקות את הדריסות מהמניפסט (רשומות 9/9ב/13 ב-`handoff/FROM_GAME_PENDING.md`) — לא לנקות לפני!

## מה לא לעשות
- לא לגעת ב-`storage.rules` / `firestore.rules` — פרוסים ונכונים.
- לא לבנות גרסה ולא לדחוף תגים — בניית v1.1.1 ממתינה לאישור v1.1.0 בחנויות (מטופל בפרומפט נפרד).
- לא לנקות את המניפסט החי לפני ש-v1.1.1 זמין למשתמשים.
