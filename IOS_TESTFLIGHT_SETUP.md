# התקנה על אייפון דרך Codemagic + TestFlight

מסמך זה (GitHub בלבד) מסביר מה צריך להגדיר כדי לבנות ולהתקין את WhoIsThere
על אייפון לבדיקה, בלי Mac מקומי. הקוד כבר מוכן (`codemagic.yaml`, Firebase iOS,
AdMob). מה שנשאר הוא הגדרות בקונסולות — אלו דברים שדורשים את החשבונות שלך.

מזהה האפליקציה ל-iOS: **`com.rotem.whoisthere`**

---

## שלב 1 — App Store Connect (חד-פעמי)
1. היכנס ל-https://appstoreconnect.apple.com → **My Apps → +** → New App.
2. Platform: iOS · Bundle ID: בחר/צור **`com.rotem.whoisthere`**
   (אם לא קיים, צור אותו ב-developer.apple.com → Identifiers → App ID חדש).
3. שמור. אין צורך למלא צילומי מסך/תיאור עבור TestFlight פנימי.

## שלב 2 — מפתח App Store Connect API (חד-פעמי)
1. App Store Connect → **Users and Access → Integrations → App Store Connect API**.
2. צור מפתח חדש עם הרשאת **App Manager**. הורד את קובץ ה-`.p8` (אפשר פעם אחת!).
3. רשום: **Issuer ID**, **Key ID**.

## שלב 3 — Codemagic (חד-פעמי)
1. היכנס ל-https://codemagic.io עם GitHub וחבר את הריפו `rotem-ya/WhoIsThere`.
2. **Teams → Integrations → App Store Connect → Add key**:
   - העלה את ה-`.p8`, הזן Issuer ID + Key ID.
   - תן למפתח שם **בדיוק**: `WhoIsThere ASC Key`
     (זה השם שמופיע ב-`codemagic.yaml` תחת `integrations`).
3. זהו — חתימת הקוד אוטומטית (Codemagic ייצור Provisioning Profile לבד).

## שלב 4 — הרצה
1. ב-Codemagic, פתח את האפליקציה → בחר workflow **`WhoIsThere iOS — TestFlight`** → **Start new build**.
2. בסיום (≈15–25 ד׳) הבילד יעלה אוטומטית ל-TestFlight.

## שלב 5 — התקנה על האייפון
1. התקן את אפליקציית **TestFlight** מ-App Store.
2. App Store Connect → TestFlight → הוסף את עצמך כ-Internal Tester (במייל של ה-Apple ID שלך).
3. פתח TestFlight באייפון → התקן את WhoIsThere. ✅

---

## מה עובד בבילד הראשון
- ✅ המשחק המלא במצב **אורח** (Anonymous) — Firebase/Firestore עובדים (תוקנו ערכי ה-iOS).
- ✅ פרסומות מושבתות (`adsEnabled=false`) — לא קורס (נוסף `GADApplicationIdentifier`).

## מה עדיין לא יעבוד (דורש הגדרה נוספת — אפשר בסבב שני)
- 🔶 **Google Sign-In**: ה-`GoogleService-Info.plist` חסר `CLIENT_ID`.
  ב-Firebase Console → Authentication → Sign-in method → הפעל **Google**, ודא שאפליקציית
  ה-iOS (`com.rotem.whoisthere`) רשומה, הורד מחדש את `GoogleService-Info.plist`
  (יכלול `REVERSED_CLIENT_ID`), והחלף את הקובץ ב-`ios/Runner/`. אז אוסיף את ה-URL scheme.
- 🔶 **Sign in with Apple**: צריך להפעיל את ה-capability על ה-App ID
  ב-developer.apple.com → Identifiers → `com.rotem.whoisthere` → סמן **Sign in with Apple**.
  אחרי שתעשה זאת, תגיד לי ואוסיף את קובץ ה-entitlements לפרויקט.

> טיפ: לבדיקת המשחק עצמו אין צורך בהתחברות — מצב אורח מספיק. אפשר להעלות בילד
> ראשון עכשיו ולהוסיף את ההתחברויות בסבב נפרד.
