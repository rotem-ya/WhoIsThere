# פרומפט מסירה ל-CO — גרסה 1.4.3 (מוכן להעתקה)

> העתק את הבלוק שבין הקווים ושלח ל-CO יחד עם שני הזיפים:
> `whoisthere_v1.4.3_CO_MAIN.zip` + `whoisthere_v1.4.3_CO_ipad_screens.zip`.

---

היי. המשימה: להגיש עדכון **1.4.3** של האפליקציה **"מה בתמונה?"** ל-Google Play ול-App
Store. צירפתי שני זיפים עם כל מה שצריך.

**קודם כול פתח את `START_HERE.md` בזיפ הראשי ותעבוד לפיו בדיוק.** שם כתוב הכל צעד-אחר-צעד.

בקצרה:
1. **טקסטים:** כל הטקסטים לשתי החנויות מוכנים בתיקיית `texts/` (גוגל + אפל), בתוך
   מגבלות התווים, בעברית. להעתיק כמו שהם — **בלי לערוך, בלי לשנות את שם האפליקציה.**
2. **צילומי מסך:** בתיקיית `screenshots/` — `play/` (7), `apple/` (7). צילומי ה-iPad
   (7) נמצאים בזיפ השני `..._ipad_screens.zip`. להעלות בסדר 01→07.
3. **הבילד (AAB):** נבנה ב-GitHub Actions (workflow "Build AAB", גרסה 1.4.3). כשהוא
   מוכן — הורד את ה-artifact **`GuessThePlace-playstore-aab`** (הקובץ `app-release.aab`)
   והעלה אותו ל-Google Play → Production (או Testing אם נבחר גל הדרגתי).
4. **iOS:** הבילד עולה ל-TestFlight דרך Codemagic. ב-App Store Connect צור גרסה 1.4.3,
   קשר את הבילד מ-TestFlight, מלא טקסטים+צילומים, ו-Submit for Review.
5. **אחרי הפרסום:** עדכן באדמין `app_config/app.latestBuild` ל-versionCode של הבילד
   שהוגש (מספר ריצת ה-Build AAB).

**חשוב:**
- אם Google Play דוחה "version code already used" — הבילד צריך להיבנות שוב (רותם מריץ
  Build AAB שוב, המספר יעלה). אל תשנה ידנית versionCode.
- אם משהו דורש **הרשאה/אישור אנושי או 2FA** (למשל הלחיצה הסופית "Submit", או הוספת
  בודק ב-TestFlight) — **עצור ורשום לי בדיוק מה חסר**, אל תנחש ואל תמציא.
- אין מקף ארוך ואין ניסוחים שנשמעים כמו AI בטקסטים — הם כבר נקיים, רק להעתיק.

תודה! אם משהו לא ברור — START_HERE.md עונה על רוב השאלות (יש שם גם FAQ).

---

## תזכורת לרותם (לא ל-CO) — 2 פעולות לפני שינה
הבילדים נבנים רק ב-CI, ואי אפשר להאציל את זה ל-CO:
1. **AAB:** GitHub → Actions → **Build AAB** → Run workflow → `build_name=1.4.3`,
   ענף `claude/whoishere-visual-sound-rjcdzb`.
2. **iOS:** דחיפת תג `ios-v17` מהענף (או לבקש מקלוד לדחוף):
   `git fetch origin && git tag ios-v17 origin/claude/whoishere-visual-sound-rjcdzb && git push origin ios-v17`
