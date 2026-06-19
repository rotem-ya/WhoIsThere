# AdMob — הקמת חשבון וקבלת מזהי פרסומות (לפני הפעלת פרסומות)

## מה זה AdMob ולמה צריך
**AdMob** היא מערכת הפרסומות של גוגל לאפליקציות. היא מספקת לך **מזהים (IDs)** שמחברים את
האפליקציה לחשבון שלך, כדי שתקבל כסף על הפרסומות. בלי המזהים האמיתיים האלה — האפליקציה משתמשת
ב**מזהי בדיקה** של גוגל, שאסור להציג למשתמשים אמיתיים (הפרה של מדיניות + 0 הכנסה).

**מה בחרת להציג:** פרסומת מתוגמלת (Rewarded — "צפה וקבל מטבעות") + פרסומת מעבר
(Interstitial — מסך מלא בין משחקים). **בלי באנרים.**

---

## שלב 1 — צור חשבון AdMob (חינם)
🔗 https://admob.google.com → **Sign up** (עם אותו חשבון Google).
- מלא מדינה (ישראל), אזור זמן, ואשר תנאים.
- (לתשלומים בעתיד צריך למלא פרטי מיסוי+בנק ב-Payments — לא חובה כדי להתחיל.)

## שלב 2 — רשום את שתי האפליקציות (iOS + Android)
ב-AdMob → **Apps** → **Add app**. עשה זאת **פעמיים**:
1. **iOS** — אם האפליקציה עדיין לא בחנות, בחר "No" ל-"Is your app listed?" ותן שם `מה בתמונה?`.
2. **Android** — אותו דבר, פלטפורמה Android.

> בסיום כל אחת תקבל **App ID** בפורמט `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (עם `~`).
> רשום את שניהם (iOS App ID + Android App ID).

## שלב 3 — צור יחידות פרסום (Ad units) לכל אפליקציה
בכל אפליקציה → **Ad units** → **Add ad unit**. צור **שתיים** בכל פלטפורמה:
1. **Rewarded** → שם `rewarded_coins`.
2. **Interstitial** → שם `interstitial_between_games`.

> כל יחידה נותנת **Ad unit ID** בפורמט `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` (עם `/`).
> בסך הכול יהיו לך **4 unit IDs** (2 פלטפורמות × 2 פורמטים) + **2 App IDs**.

---

## שלב 4 — שלח לי בדיוק את 6 הערכים האלה
העתק-הדבק לי בצ'אט (אפשר בלי סודיות — אלה מזהים פומביים, לא סיסמאות):

```
iOS App ID:            ca-app-pub-______________~__________
Android App ID:        ca-app-pub-______________~__________
iOS Rewarded unit:     ca-app-pub-______________/__________
Android Rewarded unit: ca-app-pub-______________/__________
iOS Interstitial unit: ca-app-pub-______________/__________
Android Interstitial:  ca-app-pub-______________/__________
```

## שלב 5 — מה אני אעשה ברגע שאקבל אותם
1. אחליף את ה-IDs ב-`lib/core/constants/ad_constants.dart`, ב-`ios/Runner/Info.plist`
   (`GADApplicationIdentifier`) וב-`android/app/src/main/AndroidManifest.xml` (`APPLICATION_ID`).
2. אממש פרסומת **Rewarded** אמיתית (כרגע "צפה בפרסומת" רק נותן מטבעות בלי להציג פרסומת —
   אתקן שזה יציג פרסומת ויתגמל רק בסיום צפייה) ופרסומת **Interstitial** בין משחקים (עם תקרת תדירות).
3. אוסיף **ATT** (App Tracking Transparency) ל-iOS — חובה של אפל כשמשתמשים במזהה פרסום.
4. אפעיל `AdConstants.adsEnabled = true`, ואסתיר באנרים (לא ביקשת).
5. נבדוק עם פרסומות-בדיקה בבילד TestFlight/אמולטור לפני שמשחררים.

---

---

## ✅ סטטוס: הוטמע (19/06/2026)

המזהים האמיתיים התקבלו והוטמעו בקוד. פרסומות **מופעלות** (`AdConstants.adsEnabled = true`).

**המזהים (publisher `ca-app-pub-8795917295916240`):**
```
Android App ID:        ca-app-pub-8795917295916240~6423959619
iOS App ID:            ca-app-pub-8795917295916240~3606224584
Android Rewarded:      ca-app-pub-8795917295916240/5386210117
Android Interstitial:  ca-app-pub-8795917295916240/7385687498
iOS Rewarded:          ca-app-pub-8795917295916240/6787187623
iOS Interstitial:      ca-app-pub-8795917295916240/7162326216
```

**מה הוטמע:**
- `lib/core/constants/ad_constants.dart` — IDs אמיתיים, `interstitialUnitId` חדש, `adsEnabled=true`, `bannersEnabled=false` (אין יחידת באנר — באנרים מנוטרלים בנפרד).
- `android/.../AndroidManifest.xml` + `ios/Runner/Info.plist` — App IDs אמיתיים.
- `lib/services/ad_service.dart` — שירות חדש: טעינה מראש + הצגה של Rewarded ו-Interstitial, תגמול רק בסיום צפייה, תקרת תדירות 2 דק' ל-Interstitial.
- `adServiceProvider` ב-`providers.dart` (preload בהפעלה).
- Rewarded: מסך חנות (`_RewardedAdTile`) + כפתור בית — מציגים פרסומת אמיתית, ומזכים מטבעות רק אם נצפתה.
- Interstitial: מוצג ביציאה מ"מסך הניצחון" לבית (בין משחקים), עם תקרת תדירות.

**⏳ נותר (iOS בלבד, לא חוסם השקת Android):**
- [ ] **ATT prompt** — נוסף `NSUserTrackingUsageDescription` ל-Info.plist, אך עדיין אין קריאת `requestTrackingAuthorization` (דורש חבילת `app_tracking_transparency`). בלי זה iOS מגיש פרסומות לא-מותאמות אישית (תקין להשקה). להוסיף לפני הגשת iOS.
- [ ] בדיקה בבילד אמיתי שהפרסומות נטענות ומוצגות.

---

## החלטת לוח-זמנים (חשוב)
הקמת AdMob + מימוש + בדיקה לוקחת זמן. שתי אפשרויות:
- **A — להשיק עכשיו בלי פרסומות, ולהוסיף פרסומות בעדכון 1.1 מהר אחריו.** המהיר ביותר ל-review;
  הקוד כבר מוכן (הכל מגודר ב-`adsEnabled`).
- **B — לחכות עם ההגשה עד שהפרסומות מוטמעות ונבדקות, ולהגיש עם פרסומות.** איטי יותר.

אם לא תגיד אחרת — ההמלצה שלי היא **A** (לא לעכב את ההשקה בגלל פרסומות).
