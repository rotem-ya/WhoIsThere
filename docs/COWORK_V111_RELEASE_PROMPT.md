# פרומפט ל-cowork — הוצאת v1.1.1 ("גרסת ההכנסות") לשתי החנויות

עבוד עם רותם שלב-שלב: כל פעולה בממשק — בקש, המתן לאישור, המשך. **הענף היחיד לבנייה: `claude/qa-launch-prep-EXqLn`.**

## מה בגרסה (ל"מה חדש" ולהקשר)
v1.1.1, build 61. עיקרי: **מודעות אמיתיות מופעלות לראשונה** (v1.0/v1.1.0 יצאו עם מודעות בדיקה = אפס הכנסה!), SKAdNetwork ל-iOS, פרומפט דירוג, Analytics, מיקומי rewarded חדשים (הכפלת פרס יומי, רמז בצפייה, מטבעות ניחומים), **פוש להזמנות חברים**, **קטלוג קוסמטיקה חי מהאדמין** (כולל רקעי Gemini), משוב עם לוג מצורף, תיקון גדלי טקסט באנדרואיד, 12 תמונות חדשות/מעודכנות, הוסרו קטגוריות ציפורים ופרחים, כל הדפים ב-Firebase Hosting.

## שלב 0 — בדיקת שער: מה מצב v1.1.0?
1. **App Store Connect:** אם 1.1.0 (build 1061) עדיין **Waiting for Review** — שאל את רותם: לבטל את ההגשה ולהגיש 1.1.1 במקומה (מאפס את התור), או לחכות לאישור. אם אושרה — ממשיכים רגיל.
2. **Play Console:** אם versionCode 25 עדיין בבדיקה — העלאת AAB חדש לאותו track פשוט מחליפה אותו; בסדר להמשיך.

## שלב 1 — ⚠️ חובה לפני בילד iOS: Push capability
ה-entitlements כוללים עכשיו `aps-environment` — **בלי הצעד הזה החתימה ב-Codemagic תיכשל:**
1. Apple Developer → Certificates, Identifiers & Profiles → **Identifiers** → `com.rotem.whoisthere` → סמן **Push Notifications** → Save.
2. (מומלץ באותה הזדמנות, נדרש לפעולת הפוש בפועל:) Keys → צור מפתח **APNs** ‏(.p8) → העלה ב-Firebase Console → Project settings → Cloud Messaging → Apple app configuration (עם Key ID + Team ID).

## שלב 2 — בילד iOS (Codemagic)
מהמחשב של רותם (ל-agent אין הרשאת תגים):
```bash
git clone https://github.com/rotem-ya/WhoIsThere.git && cd WhoIsThere
git fetch origin claude/qa-launch-prep-EXqLn
git tag ios-v4 origin/claude/qa-launch-prep-EXqLn && git push origin ios-v4
```
(או: Codemagic UI → Start build על הענף, workflow `ios-testflight`.)
- הבילד עולה אוטומטית ל-TestFlight. build name 1.1.1, מספר אוטומטי.
- אם החתימה נכשלת על entitlements — שלב 1 לא הושלם; אחרי סימון ה-capability צריך רענון פרופיל (Codemagic מחדש אוטומטית בריצה הבאה).

## שלב 3 — Android AAB
**הבילד כבר רץ** (קלוד הדליק את ה-marker). Actions → **Build AAB** → הריצה האחרונה:
1. ודא ירוק + בלוג שלב האימות מופיע `SHA1: EA:3B` וversionCode ≥ 26.
2. הורד את ה-artifact ‏(app-release.aab).
3. Play Console → Testing → Closed testing (Alpha) → Create new release → העלה → "מה חדש":
```
גרסה 1.1.1 — חדש: התראות פוש להזמנות ממשחקים וחברים, פריטי חנות חדשים
שמתעדכנים בלי עדכון אפליקציה, פרסים כפולים בצפייה בפרסומת, רמז חינם
כשנגמרים המטבעות, תיקוני תצוגה באנדרואיד, תמונות חדשות ושיפורי יציבות.
```
4. **הצהרת מודעות:** App content → Ads → ודא שמסומן **"Yes, my app contains ads"** (v1.1.1 מציגה מודעות אמיתיות לראשונה). אם Data safety לא מצהיר על Advertising ID — לעדכן (נאסף ע"י AdMob).
5. שלח לבדיקה.

### הערת הכנסות (ידיעה, לא חוסם)
המודעות יוצגו מיד, אבל הכסף תלוי ב: (א) השלמת פרטי תשלום+מס ב-AdMob (שלב 1 הישן — PIN בדואר); (ב) אימות app-ads.txt (רץ, עד 24ש׳); (ג) אימות האפליקציה ב-AdMob דורש דף חנות ציבורי — ב-Closed Testing ההצגה עלולה להיות מוגבלת עד המעבר ל-Open/Production. ⚠️ לרותם: לא לצפות שוב ושוב במודעות של עצמך — invalid traffic מקפיא חשבונות.

## שלב 4 — App Store Connect
1. אחרי שהבילד מ-TestFlight מעובד: My Apps → מה בתמונה? → ⊕ גרסה חדשה **1.1.1**.
2. בחר את הבילד החדש, הזן "מה חדש" (אותו טקסט מלמעלה), ודא Privacy/Support URLs על `whoisthere-380fa.web.app` (משלב 3 הקודם).
3. **הצהרת פרטיות/ATT:** כבר מוגדרת מ-v1.1.0 (מודעות + ATT) — אין שינוי.
4. Submit for Review.

## שלב 5 — אחרי ששתי הגרסאות באוויר (לא לפני!)
1. **פריסת Cloud Functions לפוש** (אם לא נעשה): `firebase deploy --only functions` מהריפו (ענף ההשקה, מדריך ב-PUSH_NOTIFICATIONS_SETUP.md).
2. **אדמין → "📲 הגדרות אפליקציה (חי)"**: הזן `latestBuild=61`, enabled=true, שמור → משתמשי הגרסאות הישנות יקבלו הודעת "עדכון זמין".
3. **ניקוי דריסות שהוטמעו** (רשומות 9/9ב/13 ב-`handoff/FROM_GAME_PENDING.md` באדמין): לכל דריסת תמונה שהוטמעה בבילד — נקה את ה-override במניפסט (↩️ במסך 📡). לא נוגעים ברקעי הקוסמטיקה — הם חיים מהענן בכוונה.
4. דווח לרותם צ'קליסט ✔/✘ + תזכורת: אחרי v1.1.1 באוויר מגיע שלב 6 (מעבר לריפו פרטי) — פרומפט נפרד קיים.

## אזהרות
- לא לבנות משום ענף אחר.
- לא לנקות את המניפסט לפני ששתי הגרסאות זמינות למשתמשים.
- אם AdMob עדיין בלי פרטי תשלום (שלב 1 הישן) — המודעות ירוצו אבל הכסף יחכה; להשלים במקביל.
