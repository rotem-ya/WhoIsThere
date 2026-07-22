# הנחיה ל-CO: הכן את כל הגשת עדכון 1.4.3, כולל האודיו

**משימה:** הכן מקצה לקצה את הגשת עדכון **1.4.3** של "מה בתמונה?" לשתי החנויות, כולל
הפקת קבצי האודיו החסרים.

**מקור אמת:** ריפו `rotem-ya/WhoIsThere`, ענף `claude/whoishere-visual-sound-rjcdzb`,
גרסה `1.4.3+103`. תעבוד לפי המסמכים בענף ואל תמציא טקסטים:
`docs/COWORK_SUBMIT_v1.4.3.md`, `docs/STORE_LISTING_TEXTS_v1.4.0.md`,
`docs/COWORK_STORE_SCREENSHOTS.md`, `docs/AUDIO_FILES_TODO.md`.

**עובדות:**
- 1.4.1 (Candy) כבר חיה בגוגל. 1.4.3 = עדכון תוכן+פוליש (גלגל מזל, משימות יומיות, טבלת
  מובילים שבועית, ערכות רקע, אנימציות, סאונד). אין שינוי בכללי המשחק.
- חוקי Firestore לטבלה השבועית כבר נפרסו וחיים — אין פעולה שם.
- targetSdk נשאר 35 (שדרוג API 36 מתוכנן ל-1.4.4, `docs/TARGET_API36_TODO.md`).

---

## שלב A — אודיו (לעשות ראשון, כי חייב להיכנס לבילד)
כל ה-hooks כבר בקוד; חסרים רק הקבצים. הפק/השג אותם **לפי `docs/AUDIO_FILES_TODO.md`**
בדיוק (שם + נתיב + אורך + אופי), והוסף לענף.

**8 אפקטים → `assets/sounds/ui/` (פורמט `.ogg`):**
`transition.ogg`, `streak.ogg`, `tile_flip.ogg`, `coin_shower.ogg`, `spin_tick.ogg`,
`spin_land.ogg`, `quest_complete.ogg`, `heartbeat.ogg`.

**3 מוזיקות → `assets/sounds/` (פורמט `.mp3`, לופ חלק seamless):**
`music_menu.mp3`, `music_lobby.mp3`, `music_win.mp3`.

דרישות:
- **רישוי:** רק אודיו royalty-free / בעל רישיון מסחרי מתאים לחנויות (למשל ספריות
  free-to-use עם ייחוס-לא-נדרש, או רישיון בתשלום). לתעד את המקור/הרישיון בקובץ
  `assets/sounds/CREDITS.md`.
- שמות ונתיבים **מדויקים** (אחרת הקוד נשאר שקט). עוצמות מנורמלות (~-3dB peak), בלי
  קליקים בקצוות. מוזיקה חייבת לופ חלק.
- לבצע commit לענף. ⚠️ **חייב להיכנס לפני שרותם מריץ את הבילד**, אחרת 1.4.3 יֵצא בלי
  הסאונד (fail-soft, שקט) — ואז האודיו יחכה לבילד הבא.
- לא לגעת בקבצי `ui/*.ogg` הקיימים (click/coin_gain/rank_up וכו').

בדיקה: להכניס קובץ אחד, לבנות, להפעיל את הרגע המתאים באפליקציה. אם שקט — לתקן שם/נתיב.

## שלב B — הכנת חנויות (לא דורש בילד)
**Google Play:**
1. Draft release ב-Production (או Internal testing לגל הדרגתי) — בלי AAB עדיין.
2. "מה חדש" (he-IL) מ-`STORE_LISTING_TEXTS`. תיאור קצר/מלא — לוודא תואם.
3. הכן להחלפת צילומי טלפון: תיקיית `play/` (סדר 01→07) כשרותם מעביר zip.

**App Store Connect:**
4. גרסה חדשה 1.4.3. Subtitle / Promotional / Description / Keywords / What's New —
   הכל מ-`STORE_LISTING_TEXTS`.
5. הכן להחלפת צילומים: iPhone 6.7" (`apple/`) + iPad 13" (`ipad/`), סדר 01→07.

## שלב C — גייטים של רותם (אין ל-CO הרשאת Actions/Codemagic)
6. **AAB:** רותם מריץ Actions → Build AAB → `build_name=1.4.3` (אחרי שהאודיו בענף).
   כשמוכן → CO מעלה ל-Draft ומגיש. "version code already used" → רותם מריץ שוב.
7. **iOS:** רותם דוחף תג `ios-v*` → Codemagic → TestFlight. כשבטסטפלייט → CO מקשר
   לגרסה 1.4.3 ומגיש.

## שלב D — אחרי הפרסום
8. עדכון באדמין `app_config/app.latestBuild` ל-**103**.

---

**כללי סגנון:** בלי מקף ארוך, בלי "AI tells" בטקסט גלוי (`docs/NO_AI_TELLS_STYLE.md`).
לא לשנות את שם האפליקציה.

**החזר צ'קליסט סטטוס:** אילו קבצי אודיו הוכנו (+מקור/רישיון), מה בחנויות מוכן, מה
ממתין לרותם (AAB / תג iOS / zip צילומים), ומה חסר.
