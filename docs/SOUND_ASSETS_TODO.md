# קבצי סאונד להוספה — שלב 0 (תשתית סאונד)

הקוד כבר מחווט ומחכה לקבצים. כל סאונד מנוגן דרך `SfxService` (fail-soft): **כל עוד הקובץ חסר — פשוט אין צליל, שום קריסה.** ברגע שתפיל קובץ עם השם המדויק לתיקייה `assets/sounds/ui/`, הצליל מתחיל לעבוד בלי שינוי קוד.

## מה להפיל ואיפה
תיקיית יעד: **`assets/sounds/ui/`**
פורמט מומלץ: **`.ogg`** קצר (עד ~300ms לקליקים), מנורמל לעוצמה אחידה. אם יש רק `.wav` — אפשר, פשוט שנה את הסיומת גם ב-`sfx_service.dart` (או המר ל-ogg כדי לחסוך משקל).

| שם קובץ (חובה מדויק) | האירוע | מקור CC0 מומלץ (Kenney) |
|---|---|---|
| `ui_click.ogg` | לחיצה על כפתור רגיל (כל `AppFeedback.tap`) | UI Audio — `click1` / `click_001` |
| `ui_cta.ogg` | כפתור ראשי / CTA (כל `GradientButton`) | Interface Sounds — `confirmation_001` |
| `ui_back.ogg` | ביטול / חזרה (`AppFeedback.back`) | Interface Sounds — `back_001` |
| `ui_tab.ogg` | מעבר בין טאבים (חנות) | UI Audio — `select_002` / tick |
| `sheet_open.ogg` | פתיחת bottom sheet (כל `AppBottomSheet.show`) | Interface — `drop_002` |
| `sheet_close.ogg` | סגירת bottom sheet | Interface — `minimize_001` |
| `coin_gain.ogg` | קבלת מטבעות | Casino Audio — `coin_01` |
| `coin_spend.ogg` | הוצאת מטבעות | Casino Audio — `chip_lay_01` |
| `denied.ogg` | פעולה חסומה — אין מספיק מטבעות | Interface — `error_002` |
| `notify.ogg` | באנר חברות / הזמנה / קבוצה נכנס | Interface — `question_002` |
| `chat_pop.ogg` | הודעת צ'אט נכנסת | UI Audio — `pop` |

## מקורות (CC0 — חינם לשימוש מסחרי, בלי ייחוס)
- Kenney UI Audio — https://kenney.nl/assets/ui-audio
- Kenney Interface Sounds — https://kenney.nl/assets/interface-sounds
- Kenney Casino Audio — https://kenney.nl/assets/casino-audio

## מה כבר מחווט בקוד (שלב 0)
- `ui_click` / `ui_cta` — דרך `AppFeedback.tap()` / `.primary()` → מכסה אוטומטית את `GradientButton` וכל לחצן שמשתמש ב-`AppFeedback`.
- `ui_tab` — מאזין ה-`TabController` במסך החנות.
- `sheet_open` / `sheet_close` — `AppBottomSheet.show()` (נקודת חנק אחת לכל הגיליונות שעוברים דרכה).
- `ui_back` — עוזר `AppFeedback.back()` זמין; יחובר לכפתורי החזרה בהמשך.
- `coin_gain` / `coin_spend` / `denied` / `notify` / `chat_pop` — ה-API קיים ב-`SfxService`; החיווט לאתרי הקריאה יתווסף בהמשך השלב (חלקם בקבצים ש-session מקביל נוגע בהם, אז בזהירות).

## הערות
- כל הצלילים מכבדים אוטומטית את סליידר "אפקטים" בהגדרות (`sfxVolume`). אין צורך לגעת בזה.
- ה-haptics לא הושפעו — נשמרו כפי שהיו.
- אחרי הפלת הקבצים: `flutter pub get` (רק אם הוספת פורמט/שם חדש) ובנייה. אין צורך לגעת ב-`pubspec` — התיקייה כבר רשומה.
