# פרומפט ל-cowork — משימת-על: שחרור v1.1.1 + תיקון app-ads.txt + הכנות הכנסה

עבוד עם רותם **שלב-שלב, לפי הסדר הזה בדיוק**: לכל פעולה בממשק — הסבר מה ללחוץ, המתן לאישור/צילום, סמן ✔ והמשך. אל תדלג ואל תקבץ. **הענף היחיד לבנייה: `claude/qa-launch-prep-EXqLn`.**

## הקשר קצר
- v1.1.1 (build 61) מוכנה בענף ההשקה. **בילד ה-AAB כבר רץ** (קלוד הדליק).
- זו "גרסת ההכנסות": מודעות אמיתיות לראשונה (הקודמות יצאו עם מודעות בדיקה!), פוש להזמנות, קטלוג חנות חי מהאדמין, ועוד.
- ל-AdMob יש אזהרת app-ads.txt — הקובץ תקין ובאוויר (`https://whoisthere-380fa.web.app/app-ads.txt`); הבעיה היא שאתר המפתח בחנויות עוד לא מצביע לשם. מטופל במשימה 1.

---

## משימה 1 — כתובות בחנויות (מתקן גם את אזהרת AdMob)
### Play Console (com.whoisthere.app)
- [ ] Grow → Store presence → **Store settings** → Contact details → **Website** = `https://whoisthere-380fa.web.app`
- [ ] Store presence → Main store listing → **Privacy policy** = `https://whoisthere-380fa.web.app/privacy/`
- [ ] שמור (עדכון פרטי חנות בלבד — לא דורש בילד).

### App Store Connect (Apple ID 6776076758)
- [ ] App Information → **Privacy Policy URL** = `https://whoisthere-380fa.web.app/privacy/`
- [ ] **Support URL** = `https://whoisthere-380fa.web.app/support/` · **Marketing URL** = `https://whoisthere-380fa.web.app`
- [ ] אם שדות הגרסה נעולים (1.1.0 בבדיקה) — לעדכן מה שפתוח ולרשום מה נדחה; משלימים בשלב הגשת 1.1.1 (משימה 5).

### AdMob
- [ ] Payments → ודא שפרטי תשלום + מס הושלמו (אם לא — להשלים עכשיו; PIN בדואר לוקח שבועות, שלא יעכב).
- [ ] Apps → האפליקציה → **app-ads.txt** → "בדוק עדכונים" (אחרי שעדכון ה-Website פורסם; סריקה עד 24ש׳).
- [ ] ℹ️ אם האזהרה נשארת: ב-Closed Testing דף החנות לא ציבורי וה-crawler לא רואה אותו — יסתדר במעבר ל-Open/Production. לא חוסם מודעות.

## משימה 2 — בדיקת שער: מצב v1.1.0
- [ ] **ASC:** אם 1.1.0 (build 1061) עדיין Waiting for Review — להחליט עם רותם: לבטל הגשה ולהגיש 1.1.1 (מאפס תור) או לחכות לאישור. אם אושרה — ממשיכים.
- [ ] **Play:** אם versionCode 25 עדיין בבדיקה — AAB חדש לאותו track מחליף אותו; ממשיכים רגיל.

## משימה 3 — ⚠️ חובה לפני בילד iOS: Push capability
בלי זה **החתימה ב-Codemagic תיכשל** (ה-entitlements כוללים עכשיו פוש):
- [ ] Apple Developer → Identifiers → `com.rotem.whoisthere` → סמן **Push Notifications** → Save.
- [ ] Keys → **+** → Apple Push Notifications service (APNs) → צור, הורד `.p8`, שמור Key ID + Team ID.
- [ ] Firebase Console → Project settings → **Cloud Messaging** → Apple app configuration → Upload את ה-`.p8` + Key ID + Team ID.

## משימה 4 — בילדים
### iOS (Codemagic)
מהמחשב של רותם (ל-agent אין הרשאת תגים):
```bash
git clone https://github.com/rotem-ya/WhoIsThere.git && cd WhoIsThere
git fetch origin claude/qa-launch-prep-EXqLn
git tag ios-v4 origin/claude/qa-launch-prep-EXqLn && git push origin ios-v4
```
(חלופה: Codemagic UI → Start build → הענף → workflow `ios-testflight`.)
- [ ] הבילד ירוק ועלה ל-TestFlight (build name 1.1.1, מספר אוטומטי).
- [ ] אם נכשל על entitlements/signing — משימה 3 לא נקלטה; לוודא capability ולהריץ שוב.

### Android (AAB — כבר נבנה)
- [ ] GitHub → Actions → **Build AAB** → הריצה האחרונה ירוקה.
- [ ] בלוג האימות: `SHA1: EA:3B` + versionCode ≥ 26.
- [ ] הורד את ה-artifact ‏(app-release.aab).

## משימה 5 — הגשות
### Play Console
- [ ] Testing → Closed testing (Alpha) → **Create new release** → העלה את ה-AAB.
- [ ] "מה חדש":
```
גרסה 1.1.1 — חדש: התראות פוש להזמנות ממשחקים וחברים, פריטי חנות חדשים
שמתעדכנים בלי עדכון אפליקציה, פרסים כפולים בצפייה בפרסומת, רמז חינם
כשנגמרים המטבעות, תיקוני תצוגה באנדרואיד, תמונות חדשות ושיפורי יציבות.
```
- [ ] **App content → Ads** → מסומן "Yes, my app contains ads" (מודעות אמיתיות לראשונה!). Data safety מצהיר על Advertising ID.
- [ ] שלח לבדיקה.

### App Store Connect
- [ ] אחרי שהבילד עובד ב-TestFlight: ⊕ גרסה **1.1.1** → בחר את הבילד.
- [ ] "מה חדש" (אותו טקסט) + השלמת כתובות שנדחו ממשימה 1.
- [ ] Submit for Review (הצהרת ATT/מודעות קיימת מ-v1.1.0 — אין שינוי).

## משימה 6 — אחרי ששתי הגרסאות באוויר (לא לפני!)
- [ ] **פריסת Cloud Functions לפוש** מהמחשב: `cd WhoIsThere && git checkout claude/qa-launch-prep-EXqLn && cd functions && npm install && cd .. && firebase login && firebase use whoisthere-380fa && firebase deploy --only functions`. אימות: בקשת חברות בין שני מכשירים מקפיצה פוש כשהאפליקציה סגורה.
- [ ] **אדמין → "📲 הגדרות אפליקציה (חי)"**: `latestBuild=61`, `enabled=true`, שמור → משתמשי גרסאות ישנות מקבלים "עדכון זמין".
- [ ] **ניקוי דריסות שהוטמעו** (רשומות 9/9ב/13 ב-`handoff/FROM_GAME_PENDING.md` בריפו האדמין): override-ים של תמונות שהוטמעו בבילד — לנקות במסך 📡 (↩️). **לא לגעת ברקעי הקוסמטיקה** — הם חיים מהענן בכוונה.
- [ ] דווח לרותם צ'קליסט ✔/✘ מלא. הצעד הבא בתור: מעבר לריפו פרטי (פרומפט קיים: COWORK_GO_PRIVATE_PROMPT).

## אזהרות קבועות
- לא לבנות משום ענף אחר. לא ליצור PR. לא לנקות מניפסט לפני ששתי הגרסאות זמינות.
- לרותם: לא לצפות שוב ושוב במודעות של עצמך — invalid traffic מקפיא חשבונות AdMob.
