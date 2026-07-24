# פרומפט לקלוד-אדמין — מסך "מרכז פרסים"

> העתק את הבלוק שבין הקווים אל קלוד באפליקציית האדמין (`rotem-ya/Guess_The_Place_Admin`).
> הוא בונה את מסך הניהול שיוצר ומעדכן את `rewards_config/config_v1`, שהמשחק קורא בזמן אמת.

---

**משימה:** הוסף למסך האדמין מודול חדש **"🎁 מרכז פרסים"** שמנהל את מסמך ה-Firestore
`rewards_config/config_v1` (קריאה ציבורית, כתיבה isAdmin — אותו דפוס בדיוק כמו
`cosmetics_catalog/catalog_v1` ו-`app_config/app` שכבר קיימים באדמין). המשחק קורא את
המסמך הזה בזמן אמת ומרנדר ממנו את גלגל המזל, ה-happy hour והמטלות, בלי בילד חדש.

**כללי חובה:**
- **כל הזמנים ב-UTC** בפורמט ISO-8601 (למשל `2026-07-25T17:00:00Z`). אם יש בורר תאריך/שעה
  מקומי — להמיר ל-UTC לפני הכתיבה, ולהציג המרה חזרה בקריאה.
- **`id` של מטלה הוא יציב** — לא לשנות id של מטלה קיימת (שינוי id מאפס את ההתקדמות של
  כל השחקנים למטלה). למחיקה רכה: `active:false`.
- `spin.segments` ו-`spin.weights` — **אותו אורך** (4–12; 8 מומלץ). `weights` = משקלים
  יחסיים (סכום חופשי), לא אחוזים.
- `happyHour.multiplier` — שלם 2–5.
- לבצע ולידציה לפני שמירה (אורכים תואמים, target/reward > 0, זמנים תקינים).

**סכימת המסמך `rewards_config/config_v1`:**
```json
{
  "version": 1,
  "spin": {
    "enabled": true,
    "segments": [10, 25, 50, 15, 100, 30, 75, 20],
    "weights":  [26, 18,  8, 22,   2, 14,  4, 20]
  },
  "happyHour": {
    "enabled": false,
    "multiplier": 2,
    "label": "שעת המזל!",
    "startUtc": "2026-07-25T17:00:00Z",
    "endUtc":   "2026-07-25T19:00:00Z"
  },
  "dailyQuests": [
    {"id":"win2","kind":"win","emoji":"🏆","title":"נצחו 2 משחקים","target":2,"reward":40,"active":true},
    {"id":"play3","kind":"play","emoji":"🎮","title":"שחקו 3 משחקים","target":3,"reward":30,"active":true},
    {"id":"discover5","kind":"discover","emoji":"🗺️","title":"גלו 5 מקומות","target":5,"reward":50,"active":true}
  ],
  "weeklyQuests": [
    {"id":"win15","kind":"win","emoji":"🏅","title":"נצחו 15 משחקים השבוע","target":15,"reward":150,"active":true},
    {"id":"discover20","kind":"discover","emoji":"🌍","title":"גלו 20 מקומות השבוע","target":20,"reward":120,"active":true}
  ],
  "events": []
}
```

**מסך הניהול — 4 מקטעים:**
1. **גלגל המזל:** עורך שורות של (סכום מטבעות, משקל) — הוספה/מחיקה/עריכה, מתג `enabled`,
   ותצוגה מקדימה של הסיכוי היחסי לכל פרס (משקל/סכום המשקלים).
2. **Happy Hour:** מתג `enabled`, בורר כפולה (2–5), תווית טקסט, ובורר חלון התחלה/סיום
   (UTC). להציג "פעיל עכשיו / לא פעיל" לפי הזמן הנוכחי.
3. **מטלות יומיות** ו-**4. מטלות שבועיות:** טבלת CRUD לכל אחת — שדות
   `id / kind (win|play|discover) / emoji / title / target / reward / active`. `kind`
   כבורר. אזהרה אם משנים `id` של רשומה קיימת.

**שמירה:** כתיבת המסמך כולו ל-`rewards_config/config_v1` (merge). אחרי שמירה מוצלחת
להציג אישור. אם המסמך לא קיים — ליצור אותו עם ברירות המחדל שלמעלה.

**חוזה חזרה למשחק:** רשום ב-`handoff/FROM_ADMIN_PENDING.md` (או המקבילה) שהמסמך
`rewards_config/config_v1` נוצר, כדי שקלוד-המשחק יידע שאפשר לקרוא ממנו.

**כללי סגנון:** טקסטים שנראים לשחקן (תוויות מטלות, תווית happy hour) — בעברית, בלי מקף
ארוך, בלי "AI tells".

---

## חוזה מהמשחק לאדמין (להוסיף ל-`handoff/FROM_GAME_PENDING.md` באדמין)
- **מסמך חדש:** `rewards_config/config_v1` (קריאה ציבורית, כתיבה isAdmin) — הסכימה למעלה.
- **כלל Firestore:** נוסף `match /rewards_config/{docId} { allow read: if true; allow write: if isAdmin(); }`
  ב-`firestore.rules` בריפו המשחק, נפרס מ-main.
- **תלות:** המשחק קורא את המסמך בזמן אמת (RewardsConfigService). עד שהאדמין יוצר אותו,
  המשחק משתמש בברירות מחדל מוטמעות (אין רגרסיה).
