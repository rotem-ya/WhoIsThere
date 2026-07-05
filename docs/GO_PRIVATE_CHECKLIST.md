# צ'קליסט מעבר לריפו פרטי (GO PRIVATE)

מסמך זה מרכז את **כל** התלויות של WhoIsThere בהיותו ריפו ציבורי, מה כבר טופל, ומה מבצעים (ובאיזה סדר) ביום המעבר. עודכן: 2026-07-05.

## העיקרון
ב-GitHub Free, ריפו פרטי **מאבד את GitHub Pages** (האתר ב-`rotem-ya.github.io/WhoIsThere/` יורד מהאוויר) ו**קישורי releases** דורשים התחברות. לכן כל דבר שפונה החוצה הועבר ל-**`rotem-ya/apps-share-pages`** — ריפו שנשאר ציבורי.

## ✅ מה כבר הוכן (בוצע 2026-07-05)
| פריט | כתובת חדשה (חיה ומאומתת) |
|---|---|
| מדיניות פרטיות | `https://rotem-ya.github.io/apps-share-pages/whoisthere/privacy/` |
| דף תמיכה | `https://rotem-ya.github.io/apps-share-pages/whoisthere/support/` |
| דף הזמנת חבר | `https://rotem-ya.github.io/apps-share-pages/whoisthere/friend/` |
| דף הצטרפות לחדר | `https://rotem-ya.github.io/apps-share-pages/whoisthere/join/` (היה שם מאז ומעולם) |
| דף הורדה (QA) | `https://rotem-ya.github.io/apps-share-pages/whoisthere/download/` |
| seed לאדמין | `https://rotem-ya.github.io/apps-share-pages/whoisthere/content/content_catalog_seed.json` |

בקוד האפליקציה:
- `AppConstants.friendPageUrl` הוחזר לכתובת ה-apps-share-pages (הדף חי). ה-deep-link handler וה-AndroidManifest מזהים את **שני** ה-hosts, כך שקישורים מבילדים ישנים ממשיכים לפתוח את האפליקציה.
- `joinPageUrl` תמיד הצביע על apps-share-pages ✓.
- אין בקוד שום קריאה ל-raw.githubusercontent או ל-Pages של WhoIsThere מלבד הנ"ל.
- workflow הסנכרון (`sync-join-page.yml`) עודכן לסנכרן גם support/download/seed + נוסף `workflow_dispatch` (ידרוש תיקון PAT — ראה למטה). **השינוי חייב להגיע גם ל-main** כדי להשפיע (הוא רץ על push ל-main).
- retention של artifacts קוצר (APK 3 ימים, AAB 7) — מכסת האחסון בפרטי היא 500MB.

## 🔶 שלב 1 — לפני ההפיכה לפרטי (פעולות אנושיות)
1. **תצהירי החנויות — להחליף כתובות:**
   - **Play Console** → Store presence / App content → **Privacy policy** → `https://rotem-ya.github.io/apps-share-pages/whoisthere/privacy/`
   - **App Store Connect** → App Information →
     - Privacy Policy URL → `https://rotem-ya.github.io/apps-share-pages/whoisthere/privacy/`
     - Support URL → `https://rotem-ya.github.io/apps-share-pages/whoisthere/support/`
     - Marketing URL (אם הוזן) → `https://rotem-ya.github.io/apps-share-pages/whoisthere/`
   - ⚠️ אם v1.1.0 עדיין **Waiting for Review** — שינוי app information בדרך כלל אפשרי בלי הגשה חדשה; אם הממשק דורש גרסה, לעדכן מיד אחרי האישור ו**לא להפוך לפרטי עד אז**.
2. **Codemagic:** לוודא שלחיבור ה-GitHub של Codemagic יש הרשאה ל-private repos (Teams → Integrations → GitHub). אם הבילד הבא נכשל ב-fetch — לחדש את ההרשאה.
3. **אפליקציית האדמין:** אם היא מושכת את ה-seed או כל דבר אחר מכתובת של הריפו (raw.githubusercontent / rotem-ya.github.io/WhoIsThere) — להחליף ל-seed הציבורי החדש (בטבלה למעלה). עבודה מול Firestore/Storage לא מושפעת בכלל.
4. **למזג ל-main** את עדכון `sync-join-page.yml` ואת דפי docs (support/download כבר שם; לוודא שהכל עדכני), כדי שסנכרון עתידי יעבוד אחרי תיקון ה-PAT.

## 🔶 שלב 2 — ההפיכה עצמה
GitHub → WhoIsThere → Settings → General → Danger Zone → **Change visibility → Private**.

## 🔶 שלב 3 — מיד אחרי
1. לוודא שהדפים החדשים עדיין 200 (הם ב-apps-share-pages — לא אמורים להיות מושפעים).
2. להריץ בילד APK (push קטן) ולוודא ש-Actions עובד בפרטי.
3. לוודא בילד Codemagic (תג test או Start build) — אם נכשל, לחדש הרשאת GitHub.
4. **סיבוב מפתח ההעלאה (TODO אבטחה מההשקה):** המפתח EA:3B היה חשוף בריפו ציבורי. עכשיו כשהוא מוסתר — עדיין מומלץ: Play Console → App integrity → לבקש איפוס upload key, לייצר keystore טרי עם סיסמה חזקה, לשמור כ-GitHub Secret ולהסיר את המוטמע מה-workflow. (גם `build-apk.yml` מכיל את מפתח ה-QA 25:C3 — לאותו טיפול.)

## ⚠️ מה נשבר ביום המעבר (מודע ומקובל)
- **קישורי חבר שנשלחו מבילדים v1.1.0 ומטה** מצביעים על `rotem-ya.github.io/WhoIsThere/friend.html` → יחזירו 404. ההודעה בוואטסאפ כוללת גם את הקוד עצמו ("אין אפליקציה? הקוד שלי: X") כך שחיבור ידני עדיין אפשרי. **קישורים חדשים** שישותפו מהגרסה הבאה (הקוד כבר עודכן) יעבדו. אפשרות עדינה יותר: להפוך לפרטי רק אחרי שהגרסה הבאה (עם הכתובת החדשה) באוויר.
- **קישור ההורדה הישיר של ה-QA APK** (`github.com/rotem-ya/WhoIsThere/releases/download/qa-launch/...`) ידרוש התחברות עם הרשאה לריפו — דף ההורדה הציבורי יפסיק לעבוד לאנונימיים. חלופה בהמשך: Firebase App Distribution או העלאת ה-APK כ-asset בריפו ציבורי אחר.
- **מכסות Actions בפרטי (Free):** 2,000 דקות/חודש + 500MB אחסון artifacts. ה-retention קוצר בהתאם; אם ייגמרו הדקות — לצמצם טריגרים של build-apk (רץ היום על כל push ל-`claude/**`).

## מה לא מושפע בכלל
Firebase (Firestore/Storage/Auth/Rules deploy), AdMob, החנויות עצמן, Codemagic (אחרי אימות הרשאה), עבודת ה-agent בסשנים (GitHub App), תוכן האדמין החי (מניפסט/Storage).
