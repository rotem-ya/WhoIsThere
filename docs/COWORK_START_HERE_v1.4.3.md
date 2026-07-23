# מה בתמונה? — הגשת עדכון 1.4.3 · ערכת CO מלאה (התחל כאן)

חבילה זו כוללת **כל מה שצריך** להגיש את עדכון 1.4.3 ל-Google Play ול-App Store:
טקסטים, צילומי מסך בכל הגדלים, ומדריך שלב-אחר-שלב. עבוד לפי הסדר למטה.

**גרסה:** 1.4.3 · ענף `claude/whoishere-visual-sound-rjcdzb`.
**רקע:** 1.4.1 (Candy) כבר חיה בגוגל. 1.4.3 = עדכון תוכן + פוליש (סאונדים, אנימציות,
גלגל מזל, משימות יומיות, טבלה שבועית, רצף ניצחונות, טיפ יומי). אין שינוי בכללי המשחק.
חוקי Firestore לטבלה השבועית כבר פרוסים וחיים. **שם האפליקציה לא משתנה.**

---

## ⛔ תלות אחת שאי אפשר לעקוף — הבילדים נבנים רק ב-CI
**ה-AAB (אנדרואיד) וה-IPA (iOS) לא כלולים בחבילה ולא ניתן לבנות אותם ידנית מכאן.**
הם נבנים אך ורק דרך ה-CI, וזה דורש הרשאת Actions/Codemagic שיש רק לרותם:

- **AAB:** רותם → GitHub → Actions → **Build AAB** → Run workflow → `build_name=1.4.3`
  → בסיום מורידים את ה-artifact **`GuessThePlace-playstore-aab`** (`app-release.aab`).
- **iOS:** רותם דוחף תג `ios-v*` מהענף → Codemagic בונה ומעלה ל-TestFlight אוטומטית.

אם הבילדים עדיין לא מוכנים כשמתחילים — ממתינים להם. כל שאר ההכנה (טקסטים, צילומים,
מילוי שדות) אפשר לעשות במקביל.

---

## שלב 1 — Google Play (אנדרואיד)
1. Play Console → האפליקציה → **Production** (או Internal/Closed testing לגל הדרגתי)
   → **Create new release**.
2. **App bundle:** העלה את `app-release.aab` (מה-artifact של Build AAB).
   - ה-versionCode נגזר ממספר ריצת ה-workflow ולכן גבוה מ-1.4.1. אם Play דוחה
     "version code already used" → רותם מריץ Build AAB שוב (המספר יעלה).
3. **Release name:** `1.4.3`.
4. **Release notes (he-IL):** הדבק מ-`texts/google_play/whats_new_he.txt`.
5. **דף החנות** (אם צריך רענון): תיאור קצר `texts/google_play/short_description.txt`,
   תיאור מלא `texts/google_play/full_description.txt`.
6. **צילומי טלפון:** Play Console → הופעה בחנות → דף החנות הראשי → צילומי מסך של טלפון →
   מחק ישנים → העלה את כל `screenshots/play/` (7 קבצים, 1080×2160) בסדר 01→07.
7. **Save** → **Review release** → **Start rollout to Production** (או שמור כטיוטה אם
   רותם ביקש לאשר ידנית לפני שחרור).

## שלב 2 — App Store (iOS)
1. App Store Connect → האפליקציה → **+ Version** → הקלד **1.4.3**.
2. **Build:** קשר את הבילד שעלה מ-TestFlight (מופיע אחרי שהעיבוד באפל מסתיים).
3. מלא את השדות מ-`texts/app_store/`:
   - Subtitle → `subtitle.txt`
   - Promotional Text → `promotional_text.txt`
   - Description → `description.txt`
   - Keywords → `keywords.txt`
   - What's New in This Version → `whats_new_he.txt`
4. **צילומי מסך — שני מדורים נפרדים:**
   - iPhone 6.7": העלה את כל `screenshots/apple/` (7 קבצים, 1290×2796) בסדר 01→07.
   - iPad 13"/12.9": העלה את כל `screenshots/ipad/` (7 קבצים, 2048×2732) בסדר 01→07.
   - (אם ASC דורש דווקא 2064×2752 ל-iPad — לבקש מרותם גרסה בגודל הזה.)
5. **Save** → **Add for Review** → **Submit for Review**.

## שלב 3 — אחרי שאושר/פורסם
עדכן באדמין `app_config/app.latestBuild` ל-**versionCode של הבילד שהוגש**
(מספר ריצת ה-Build AAB). זה מפעיל את התראת "עדכון זמין" למשתמשי הגרסה הישנה.

---

## שאלות נפוצות (כדי שלא תיתקע)
- **איפה כל טקסט הולך?** ראה שלבים 1–2; שם הקובץ תואם לשם השדה.
- **לשנות את שם האפליקציה?** לא. משאירים "מה בתמונה?".
- **מקף ארוך / "AI tells"?** אין. הטקסטים כבר נקיים — להעתיק כמו שהם, בלי לערוך.
- **סדר הצילומים?** לפי המספור 01→07 בכל תיקייה.
- **Play דוחה versionCode?** רותם מריץ Build AAB שוב; להעלות את ה-AAB החדש.
- **הבילד לא מוכן?** ממתינים לו; אפשר להכין את כל השאר בינתיים.
- **מדריך מפורט נוסף?** `UPLOAD_GUIDE.md` באותה תיקייה.

## תוכן החבילה
```
START_HERE.md            ← המסמך הזה
UPLOAD_GUIDE.md          ← מדריך מפורט
texts/google_play/       ← short_description, full_description, whats_new_he
texts/app_store/         ← subtitle, promotional_text, description, keywords, whats_new_he
screenshots/play/        ← 7× 1080×2160 (01–07)
screenshots/apple/       ← 7× 1290×2796 (01–07)
screenshots/ipad/        ← 7× 2048×2732 (01–07)
AAB/PUT_AAB_HERE.txt     ← איך משיגים את הבילד החתום
```
