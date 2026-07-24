# חובת targetSdk 36 (Android 16) — דדליין Google Play: 31 באוגוסט 2026

## הרקע
Google Play דורש שכל אפליקציה תטרגט **Android 16 (API 36)**. אחרי **31.8.2026**, אם
targetSdk < 36 — **לא ניתן לפרסם עדכונים**. אזהרה הופיעה ב-Play Console (2026-07).

- מצב נוכחי: `targetSdk 35`, `compileSdk` = ברירת המחדל של Flutter 3.27.4.
- toolchain נוכחי: **AGP 8.1.0**, **Gradle 8.3** (ראה `android/settings.gradle`,
  `android/gradle/wrapper/gradle-wrapper.properties`).

## למה זה נדחה מ-1.4.3
1.4.3 (targetSdk 35) מתפרסמת נקי לפני הדדליין — החסימה חלה רק על עדכונים אחרי 31.8.
השדרוג נוגע ישירות בנתיב הבילד של הפרסום (`build-aab.yml`), ולא ניתן לאמת אותו בלי
ריצת CI אמיתית, לכן הופרד כדי לא לסכן את פרסום 1.4.3.

## מה צריך לעשות ל-1.4.4 (לפני 31.8.2026)
1. `android/app/build.gradle`: להוסיף `compileSdk 36` ו-`targetSdk 36` (override על
   ברירת המחדל של Flutter).
2. `android/settings.gradle`: **AGP 8.1.0 → 8.7.x** (compileSdk 36 דורש AGP ≥ 8.7).
3. `android/gradle/wrapper/gradle-wrapper.properties`: **Gradle 8.3 → 8.9** (נדרש ל-AGP 8.7).
4. לוודא ש-CI מתקין **Android SDK Platform 36** (subosito/flutter-action בדרך כלל מושך
   אוטומטית לפי compileSdk; אם לא — להוסיף שלב `sdkmanager "platforms;android-36"`).
5. לבדוק תאימות Flutter 3.27.4 ↔ AGP 8.7 (אם יש התנגשות — לשקול שדרוג Flutter).
6. **חובה: להריץ Build AAB ולוודא ירוק לפני הגשה.** אם נכשל — לחזור אחורה (השינויים
   מבודדים לקבצי android/gradle בלבד, הפיכים).
7. לפרסם 1.4.4 לפרודקשן (אפשר קודם בבדיקה פנימית).

## אימות שהדרישה נסגרה
אחרי פרסום 1.4.4 עם targetSdk 36, Play שולח אישור והאזהרה נעלמת.
