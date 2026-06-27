# 🚀 Cowork Submission Runbook — בצע מיד, אל תשאל את רותם כלום

זהו מסמך הוראות מלא ל-cowork. **כל הטקסטים הדרושים כתובים כאן — מוכנים להעתקה.**
אל תחזור לרותם בשאלות. בצע את הכל. אם משהו דורש לחיצה אנושית בקונסולה (Play / App Store Connect),
מלא את כל השדות מהטקסטים כאן ותשאיר לרותם רק את לחיצת ה-Submit הסופית.

- **ענף הבנייה:** `claude/qa-launch-prep-EXqLn`
- **קומיט נוכחי לבנייה:** `4a4e168` (כולל מקלדת מלאה + גרש, התאמה מדויקת במשחק האותיות, הסתרת בוט)
- **Bundle / Application ID:** `com.rotem.whoisthere`
- **פרויקט Firebase:** `whoisthere-380fa`
- **שם האפליקציה:** מה בתמונה?

---

## חלק א׳ — אפל (iOS): Codemagic → TestFlight → ואז Review

### A1. הפעלת בנייה ל-TestFlight (אוטומטי דרך Codemagic)
Codemagic מוגדר ב-`codemagic.yaml` (workflow `ios-testflight`) להיבנות ולעלות אוטומטית ל-TestFlight
בעת דחיפת תג `ios-v*`. **בצע:**

```bash
git fetch origin claude/qa-launch-prep-EXqLn
git tag ios-v2 4a4e168747ae26ba523c8bb9028c1a44a3811452
git push origin ios-v2
```

(אם `ios-v2` כבר קיים — עלה ל-`ios-v3` וכו׳.)
זה מפעיל את Codemagic → בונה IPA חתום (חתימה אוטומטית, distribution app_store) → **מעלה אוטומטית ל-TestFlight**
(`submit_to_testflight: true`). זמן: ~15–25 דק׳.
דרישה מוקדמת חד-פעמית שכבר אמורה להיות מוגדרת: מפתח ASC בשם **בדיוק** `Apple_Key_Trivia` ב-Codemagic.

### A2. הגשה ל-App Store Review (אחרי שהבילד ב-TestFlight)
ב-App Store Connect → האפליקציה `מה בתמונה?` → צור גרסה `1.0.0` ל-iOS, בחר את הבילד שעלה, ומלא את השדות הבאים (טקסטים מוכנים בחלק ג׳). ואז **Add for Review → Submit**.

---

## חלק ב׳ — גוגל (Play Console): הורד AAB → העלה → Review

### B1. הורדת ה-AAB
ה-AAB החתום (מפתח העלאה SHA-1 `25:C3`) מוכן כ-artifact:
- ריצה: https://github.com/rotem-ya/WhoIsThere/actions/runs/28298928819
- artifact: **`GuessThePlace-playstore-aab`** (~98MB)

### B2. העלאה והגשה
Play Console → `מה בתמונה?` → **Production** (או Closed/Internal testing להתחלה) → **Create new release** →
העלה את ה-AAB → מלא **Release notes** (חלק ג׳) → **Save → Review release → Start rollout to Production / Submit for review**.
ודא שהושלמו: **Store listing**, **Data safety**, **Content rating**, **Target audience** (חלק ג׳).

---

## חלק ג׳ — כל הטקסטים (מוכנים להעתקה)

### שם וכותרות
- **שם אפליקציה / App Name:** `מה בתמונה?`
- **כותרת משנה (Apple Subtitle, ≤30 תווים):** `ניחוש תמונות נגד חברים`
- **קטגוריה:** משחקים → טריוויה (Trivia) ; משנית: מילים (Word)

### תיאור קצר (Google Short description, ≤80 תווים)
```
משחקי ניחוש תמונות בעברית — נגד חברים ובזמן אמת. זהו, נחשו, נצחו!
```

### טקסט קידום (Apple Promotional Text, ≤170 תווים)
```
משחקי ניחוש מהירים בעברית: זהו מקומות, חיות וצמחים, שחקו וורדל-תמונות, אספו מטבעות והתחרו מול חברים בזמן אמת!
```

### תיאור מלא (Google Full description / Apple Description)
```
מה בתמונה? — שלושה משחקי ניחוש ממכרים בעברית, חינמיים, לשחק לבד או נגד חברים בזמן אמת.

🖼️ זיהוי תמונות — חשפו את התמונה משבצת-משבצת ונחשו ראשונים מה מסתתר מאחור.
🐾 חי־צומח־דומם — חיות, פרחים, ציפורים, כלי תחבורה, מקצועות, דגלים ועוד 11 קטגוריות.
🔤 משחק האותיות — וורדל עם תמונות: נחשו את המילה אות אחר אות וחשפו את התמונה.

✨ מה מחכה לכם:
• מצב חברים — הזמינו חברים בלחיצה, התחרו ביניכם וצפו בטבלת ניקוד אישית.
• משחק בזמן אמת — תורות, ניחושים וכרטיסי פעולה (חסימה, החשכה, עצור).
• כלכלה הוגנת — אספו מטבעות, פרס יומי, ופתחו עיצובים — בלי pay-to-win.
• חנות עיצובים — מסגרות אווטר, צבעי שם, אפקטי ניצחון ורקעי לוח.
• מקלדת עברית מלאה — כולל אותיות סופיות וגרש.

הורידו עכשיו, אספו מטבעות, ותגלו מי באמת יודע מה בתמונה! 🏆
```

### מילות מפתch (Apple Keywords, ≤100 תווים, מופרד בפסיקים)
```
ניחוש,תמונות,חידון,טריוויה,מילים,וורדל,חברים,מקומות,חיות,משחק,עברית,מולטיפלייר,חינם
```

### Release notes / What's New (לשתי החנויות)
```
גרסת השקה ראשונה 🎉
• שלושה משחקים: זיהוי תמונות, חי-צומח-דומם, ומשחק האותיות.
• מצב חברים עם הזמנה בלחיצה וטבלאות ניקוד.
• חנות עיצובים, מטבעות ופרס יומי.
• מקלדת עברית מלאה עם אותיות סופיות וגרש.
```

### Data safety (Google) / App Privacy (Apple) — תשובות
האפליקציה משתמשת ב-Firebase Auth/Firestore ובפרסומות AdMob.
- **נאסף:** מזהה משתמש (חשבון Google או אורח אנונימי), נתוני משחק (ניקוד, התקדמות), מזהי מכשיר לפרסום (AdMob).
- **שיתוף עם צד שלישי:** Google AdMob (פרסום).
- **הצפנה במעבר:** כן. **מחיקת חשבון:** זמינה לבקשה.
- **אין:** מידע רגיש, מיקום מדויק, אנשי קשר, בריאות.
- **Apple Privacy "Data Used to Track You":** Identifiers (פרסום, אם AdMob non-personalized — סמן בהתאם).

### Content rating / Target audience
- **דירוג גיל:** מתאים לכולם / Everyone (אין אלימות, אין תוכן מיני, אין הימורים אמיתיים — מטבעות וירטואליים בלבד).
- **קהל יעד (Google Target audience):** 13+ (בשל פרסומות וחשבונות). אם רוצים ילדים — צריך להתאים AdMob ל-child-directed; כברירת מחדל בחר 13+.
- **שאלון Google content rating:** ענה "לא" על אלימות/מין/סמים/הימורים; "כן" שיש פרסומות; רכישות וירטואליות — מטבעות במשחק (לא כסף אמיתי, אלא אם יש IAP בפועל).

### קישורים נדרשים
- **מדיניות פרטיות (Privacy Policy URL):** השתמש בקיים בקונסולה. אם חסר — השתמש בעמוד GitHub Pages של הפרויקט או צור עמוד פרטיות סטנדרטי ופרסם תחת `apps-share-pages`.
- **Support URL / אימייל תמיכה:** `rot4735@gmail.com`.

---

## חלק ד׳ — סדר ביצוע מומלץ (התחל עכשיו)
1. **iOS:** דחוף `ios-v2` (A1) → ממתין לבנייה ב-Codemagic.
2. **Android:** במקביל — הורד AAB (B1), העלה ל-Play (B2), מלא Store listing + Data safety + Content rating (חלק ג׳), הגש.
3. כשה-iOS ב-TestFlight — מלא ASC (A2 + חלק ג׳) והגש ל-Review.
4. עדכן את רותם רק כשצריך את לחיצת ה-Submit הסופית או אם חסר Secret/הרשאה.

> הערה ל-cowork: אם דחיפת התג נכשלת אצלך גם ב-403, פתח את Codemagic UI והרץ **Start new build** על workflow `WhoIsThere iOS — TestFlight` (ענף `claude/qa-launch-prep-EXqLn`).
