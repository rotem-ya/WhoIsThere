# קובצי סאונד UI — שלב 0 (כלולים בריפו)

הקבצים נמצאים ב-**`assets/sounds/ui/`** ומחווטים דרך `SfxService` (fail-soft). כל הצלילים מכבדים אוטומטית את סליידר "אפקטים" בהגדרות (`sfxVolume`).

## רישיון
כל הקבצים הם **CC0** (Creative Commons Zero) מ-[Kenney](https://kenney.nl) — חינם לשימוש מסחרי, ללא חובת ייחוס. מקורות: [UI Audio](https://kenney.nl/assets/ui-audio), [Interface Sounds](https://kenney.nl/assets/interface-sounds), [Casino Audio](https://kenney.nl/assets/casino-audio).

## המיפוי שנבחר (קובץ בריפו → מקור Kenney → אירוע)
| קובץ ב-`assets/sounds/ui/` | מקור Kenney | האירוע |
|---|---|---|
| `ui_click.ogg` | Interface `click_001` | לחיצה על כפתור רגיל (`AppFeedback.tap`) |
| `ui_cta.ogg` | Interface `confirmation_001` | כפתור ראשי / CTA (`GradientButton`) |
| `ui_back.ogg` | Interface `back_001` | ביטול / חזרה (`AppFeedback.back`) |
| `ui_tab.ogg` | Interface `select_002` | מעבר בין טאבים (חנות) |
| `sheet_open.ogg` | Interface `open_001` | פתיחת bottom sheet (`AppBottomSheet.show`) |
| `sheet_close.ogg` | Interface `close_001` | סגירת bottom sheet |
| `coin_gain.ogg` | Casino `chips-stack-1` | קבלת מטבעות |
| `coin_spend.ogg` | Casino `chip-lay-1` | הוצאת מטבעות |
| `denied.ogg` | Interface `error_002` | אין מספיק מטבעות |
| `notify.ogg` | Interface `question_002` | באנר חברות / הזמנה / קבוצה נכנס |
| `chat_pop.ogg` | Interface `pluck_001` | הודעת צ'אט נכנסת |

## החלפת צליל
לא אהבת צליל מסוים? פשוט החלף את הקובץ **באותו שם** תחת `assets/sounds/ui/` — אין צורך לגעת בקוד. כל הקבצים קטנים (סה"כ ~108KB).

## מה מחווט בקוד (שלב 0)
- `ui_click` / `ui_cta` — `AppFeedback.tap()` / `.primary()` → כל `GradientButton` וכל לחצן דרך `AppFeedback`.
- `ui_tab` — מאזין ה-`TabController` במסך החנות.
- `sheet_open` / `sheet_close` — `AppBottomSheet.show()`.
- `ui_back` — עוזר `AppFeedback.back()` זמין; יחובר לכפתורי החזרה בהמשך.
- `coin_gain` / `coin_spend` / `denied` / `notify` / `chat_pop` — ה-API קיים ב-`SfxService`; החיווט לאתרי הקריאה יתווסף בהמשך.
