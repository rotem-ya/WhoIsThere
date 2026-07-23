# הנחיות ל-CO: העלאת גרסה 1.4.3 לגוגל ולאפל

**גרסה:** `1.4.3` · ענף `claude/whoishere-visual-sound-rjcdzb`.
**רקע:** 1.4.1 (Candy) חיה בגוגל. 1.4.3 = עדכון תוכן + פוליש גדול (סאונדים חדשים,
אנימציות, גלגל מזל, משימות יומיות, טבלה שבועית, רצף ניצחונות, טיפ יומי ועוד). אין
שינוי בכללי המשחק. חוקי Firestore לטבלה השבועית כבר פרוסים וחיים.

⚠️ **הבילד (AAB/IPA) לא נכלל בחבילה הזו — הוא נבנה רק ב-CI.** ראה שלב 0.

---

## שלב 0 — השגת הבילדים (דורש את רותם; ל-CO אין הרשאת Actions/Codemagic)
**אנדרואיד (AAB):** רותם מריץ Actions → **Build AAB** → Run workflow →
`build_name=1.4.3`. בסיום, מורידים את ה-artifact **`GuessThePlace-playstore-aab`**
(הקובץ `app-release.aab`, חתום EA:3B). ה-versionCode נגזר ממספר ריצת ה-workflow ולכן
גבוה מ-1.4.1 החי. אם Play דוחה "version code already used" — להריץ שוב.

**iOS (IPA→TestFlight):** רותם דוחף תג `ios-v*` מהענף → Codemagic בונה ומעלה ל-TestFlight
אוטומטית.

---

## שלב 1 — Google Play
1. Play Console → האפליקציה → **Production** (או Testing לגל הדרגתי) → **Create new release**.
2. העלה את `app-release.aab`.
3. **Release notes (he-IL):** הדבק מ-`google_play/whats_new_he.txt`.
4. ודא שדף החנות תואם: תיאור קצר (`short_description.txt`) ותיאור מלא
   (`full_description.txt`). **לא לשנות את שם האפליקציה.**
5. צילומי טלפון: כשרותם מעביר zip צילומים — מחק ישנים והעלה את `play/` בסדר 01→07.
6. שמור והגש לבדיקה.

## שלב 2 — Apple App Store
1. App Store Connect → האפליקציה → צור גרסה חדשה **1.4.3**.
2. קשר את הבילד מ-TestFlight (אחרי שעלה).
3. מלא מהקבצים בתיקיית `app_store/`:
   - כותרת משנה — `subtitle.txt`
   - טקסט קידום — `promotional_text.txt`
   - תיאור — `description.txt`
   - מילות מפתח — `keywords.txt`
   - מה חדש — `whats_new_he.txt`
4. צילומי מסך: iPhone 6.7" (`apple/`) + iPad 13" (`ipad/`), סדר 01→07 (שני מדורים נפרדים).
5. **Submit for Review**.

## שלב 3 — אחרי הפרסום
עדכן באדמין `app_config/app.latestBuild` ל-**versionCode של הבילד שהוגש** (מפעיל את
התראת "עדכון זמין" למשתמשי הגרסה הישנה). אם בנית עם ה-workflow, זה מספר ריצת ה-Build AAB.

---

## כללי סגנון
בלי מקף ארוך, בלי "AI tells" בטקסט גלוי. כל הטקסטים מוכנים בחבילת ה-ZIP לצד המסמך הזה
(`whoisthere_v1.4.3_store_package.zip`) — להעתיק כמו שהם.
