# קרדיטים ורישוי — אודיו

כל קבצי האודיו בגרסה 1.4.3 שנוספו לבוסט הסאונד **נוצרו במקור (procedural synthesis)**
במיוחד עבור "מה בתמונה?". אין בהם דגימות מוקלטות ולא חומר מספריות חיצוניות, ולכן
**אין תלות ברישיון צד שלישי** והם בבעלות מלאה של הפרויקט — מותרים לשימוש מסחרי בשתי
החנויות ללא ייחוס.

שיטת ההפקה: סינתזה דיגיטלית (גלי סינוס/משולש/רעש, מעטפות ADSR, פילטרים) עם NumPy,
קידוד ל‑OGG/MP3 עם libsndfile. הסקריפטים שמורים בריפו (`tools/audio/synth_sfx.py`,
`tools/audio/synth_music.py`) וניתן להריצם מחדש לשחזור מדויק (seed קבוע).

הרצה מחדש: `pip install numpy soundfile` ואז `python3 tools/audio/synth_sfx.py`
ו‑`python3 tools/audio/synth_music.py` (כותבים ישירות ל‑`assets/sounds/`).

## אפקטי סאונד — `assets/sounds/ui/*.ogg` (מקוריים, נוצרו 2026-07-22)
| קובץ | אורך | תיאור |
|------|------|-------|
| `transition.ogg` | 0.40ש' | וווש מעבר בין סבבים |
| `streak.ogg` | 0.30ש' | פינג רצף עולה |
| `tile_flip.ogg` | 0.18ש' | היפוך משבצת: וווש אוורירי + טאפ עץ רך |
| `coin_shower.ogg` | 0.80ש' | מפל מטבעות |
| `spin_tick.ogg` | 0.08ש' | טיק ראצ'ט של הגלגל |
| `spin_land.ogg` | 0.30ש' | נחיתת גלגל המזל |
| `quest_complete.ogg` | 0.70ש' | ג'ינגל השלמת משימה |
| `heartbeat.ogg` | 0.34ש' | פעימת לב בספירה לאחור |

## מוזיקת רקע — `assets/sounds/*.mp3` (מקוריות, לופ חלק, נוצרו 2026-07-22)
| קובץ | אורך לופ | אופי |
|------|----------|------|
| `music_menu.mp3` | 41.7ש' | תפריט, רגוע‑ידידותי (C‑major) |
| `music_win.mp3` | 16.0ש' | מסך ניצחון, חגיגי (C‑major) |

> **הלובי נשאר שקט בכוונה** (החלטת עיצוב) — אין מוזיקת לובי. `MenuTrack.lobby`
> ממופה ל‑silent ב‑`MusicRouteObserver`, וקובץ `music_lobby.mp3` הוסר.

הלופים נבדקו לרציפות בנקודת החיבור (junction jump נמוך משמעותית מהשונות הפנימית,
שני הקצוות סמוכים לאפס) — לופ חלק ללא קליק.

## קבצים קיימים מלפני הבוסט (לא נגענו בהם)
`background_studio.mp3`, `victory_fanfare.mp3`, `daily_coins.mp3`, `aperture_open.wav`,
`correct_ding.wav`, `guess_tick.wav`, `player_join.wav`, `wrong_buzz.wav`, וקבצי
`ui/*.ogg` הקודמים (click/coin_gain/rank_up וכו').
