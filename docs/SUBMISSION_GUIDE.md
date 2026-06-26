# הוראות הגשה ל-Review — Google Play + App Store

מסמך זה מיועד ל-**Claude cowork** שיבצע את ההגשה לחנויות אחרי שהאפליקציה מוכנה.
קרא אותו במלואו לפני שמתחילים.

> ⚠️ **מה cowork יכול ומה לא**
> - **יכול:** להריץ/לאמת בניות ב-GitHub Actions, להוריד את ה-artifact, לאמת חתימה, לקרוא לוגים, ולהדריך את האדם צעד-צעד.
> - **לא יכול:** ללחוץ בתוך Google Play Console או App Store Connect (אלה ממשקים אנושיים). שם — תן הוראות מדויקות ובקש מהמשתמש לבצע/לאשר.
> - **לעולם לא:** להחליף/לייצר מחדש keystore או תעודות, ולא לדחוף secrets לריפו. מפתח החתימה של אנדרואיד קבוע: **SHA-1 `25:C3:77:66:88:05:F4:E4:59:B5:8E:F6:DE:D2:AC:48:75:8F:46:2C`**.

---

## דרישות מקדימות (לוודא לפני הכל)
- כל הקוד שמוגש נמצא ב-`main` (מוזג + CI ירוק).
- חוקי Firestore נפרסו (`deploy-firestore-rules.yml` רץ על push ל-main).
- נכסי החנות מוכנים תחת `google-play-assets/` (כותרת, תיאורים, אייקון, feature graphic, 4 צילומי מסך, `privacy_policy_url.txt`).
- מדיניות פרטיות חיה: `https://rotem-ya.github.io/WhoIsThere/privacy.html` — ודא שהיא נטענת.
- **הצהרת מודעות:** האפליקציה כוללת AdMob (banner/interstitial/rewarded) → חובה להצהיר על מודעות + איסוף **Advertising ID** בשני הצדדים.

---

## חלק א' — Android (Google Play)

### מה כבר אוטומטי
`build-aab.yml` בונה **AAB חתום (25:C3)** כש:
- נדחף שינוי ל-`.github/aab-release.txt` ב-main, **או**
- מריצים ידנית (workflow_dispatch — אם יש הרשאה).

### צעדים
1. **הפק/אתר AAB טרי:**
   - Actions → **Build AAB (Google Play)** → הריצה האחרונה על `main` → ודא `success`.
   - אם צריך בנייה חדשה (אחרי שינוי קוד/תוכן): עדכן את התאריך/הערה ב-`.github/aab-release.txt`, commit+push ל-main (דרך PR), והמיזוג יפעיל בנייה.
2. **אמת חתימה:** בלוג הריצה, שלב *"Verify AAB signing certificate SHA"* חייב להראות `SHA1: 25:C3:…:46:2C`. אם לא — **עצור ודווח**.
3. **הורד** את ה-artifact `GuessThePlace-playstore-aab` (קובץ `app-release.aab`).
4. **העלאה ב-Play Console** (אדם):
   - Play Console → האפליקציה → **Test and release** → בחר מסלול (מומלץ קודם **Internal testing**, אח"כ **Production**) → **Create new release**.
   - העלה את `app-release.aab` → מלא **Release notes** (עברית) → **Review release** → **Start rollout**.
5. **לפני שליחה ל-Review — ודא שכל הסעיפים ב-Dashboard ירוקים:**
   - Store listing (מ-`google-play-assets/`), App content: **Privacy policy** (ה-URL), **Data safety** (כולל **Device or other IDs / Advertising ID** בגלל AdMob; וגם נתוני חשבון/משחק של Firebase), **Ads** = כן, **Content rating**, **Target audience**, **App access** (אם נדרש login — ספק לבודקים חשבון בדיקה או ציין שאפשר לשחק כאורח).
6. **חתימה ב-Play:** App integrity → ודא ש-**Upload key certificate = 25:C3**. אם Play מצפה למפתח אחר — **עצור ודווח** (אל תייצר מפתח חדש).

### אופציונלי — אוטומציית טקסטים/גרפיקה
`upload_to_play_console.py` מעלה את ה-listing (טקסטים+תמונות) דרך Service Account (Android Publisher API). **לא** מעלה את ה-binary. דורש מפתח SA עם הרשאת "Edit store listing" ב-Play Console.

---

## חלק ב' — iOS (App Store / TestFlight)

### דרישות מקדימות חד-פעמיות (אדם — לא CI)
- חשבון **Apple Developer** פעיל; רשומת אפליקציה ב-**App Store Connect** עם bundle id `com.rotem.whoisthere`.
- **App Store Connect API Key** (.p8 + Key ID + Issuer ID).
- תעודת **Distribution** (.p12 + סיסמה) ופרופיל **Provisioning** מסוג App Store.
- **7 GitHub Secrets** חייבים להיות מוגדרים:
  `APPSTORE_API_KEY_ID`, `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_KEY_P8`,
  `IOS_DIST_CERT_P12`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROVISION_PROFILE`, `APPLE_TEAM_ID`.

### צעדים
1. **ודא שכל 7 ה-secrets קיימים.** אם חסר אפילו אחד — הבנייה תיכשל; **עצור ודווח למשתמש בדיוק מה חסר** (אי אפשר ליצור אותם מה-CI).
2. הרץ: Actions → **Build iOS (TestFlight)** → **Run workflow** (workflow_dispatch). מספר ה-build נקבע אוטומטית מ-`GITHUB_RUN_NUMBER`; ה-lane `beta` (fastlane) בונה IPA חתום ומעלה ל-TestFlight דרך App Store Connect API.
3. **עקוב אחרי הריצה.** אם נכשלת — קרא את הלוג, אבחן (חתימה/פרופיל לא תואם/מפתח API), ודווח. אל תשנה תעודות.
4. אחרי הצלחה: ה-build יופיע ב-**App Store Connect → TestFlight** אחרי עיבוד (~10–30 דק').
5. **הגשה ל-App Review** (אדם):
   - App Store Connect → האפליקציה → גרסה חדשה → בחר את ה-build שעלה.
   - מלא: צילומי מסך, תיאור (עברית), keywords, Support URL, **Privacy Policy URL**, **App Privacy** (nutrition labels — סמן **Identifiers / Advertising Data** בגלל AdMob), Age Rating, **Export Compliance**, וחשבון בדיקה אם יש login (או ציין משחק כאורח).
   - **Submit for Review**.

---

## צ'ק-ליסט משותף לפני "Submit for Review"
- [ ] AAB חתום 25:C3 (אנדרואיד) / IPA עלה ל-TestFlight (iOS).
- [ ] מדיניות פרטיות חיה ומקושרת בשני הצדדים.
- [ ] הצהרת מודעות + Advertising ID בשני הצדדים (AdMob).
- [ ] Data safety (Android) + App Privacy (iOS) מלאים.
- [ ] Content rating / Age rating.
- [ ] גישת בודקים: חשבון בדיקה או הבהרה שאפשר לשחק כאורח.
- [ ] version name `1.0.0`; build number עולה אוטומטית בכל בנייה.

## אם משהו חסר/נכשל
עצור, אל תמציא ערכים ואל תייצר מפתחות חדשים. דווח למשתמש בדיוק מה חסר (secret/שלב ידני/אישור) ובקש ממנו להשלים.
