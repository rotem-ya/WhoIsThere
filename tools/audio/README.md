# tools/audio — סינתזת האודיו של המשחק

סקריפטים שמייצרים מאפס את קבצי הסאונד של בוסט 1.4.3. כל הפלט **מקורי** (ללא דגימות/
ספריות חיצוניות), ולכן ללא תלות רישיון. פרטים מלאים: `assets/sounds/CREDITS.md`.

## תלויות
```
pip install numpy soundfile
```

## הרצה
```
python3 tools/audio/synth_sfx.py     # 8 אפקטים -> assets/sounds/ui/*.ogg
python3 tools/audio/synth_music.py   # 3 מוזיקות לופ -> assets/sounds/*.mp3
```
הסקריפטים כותבים ישירות אל תיקיות ה‑assets (נתיבים מוחלטים בראש כל קובץ; לעדכן אם
הריפו לא ב‑`/home/user/WhoIsThere`). ה‑seed קבוע כך שהפלט זהה בכל הרצה.

## עקרונות
- SFX: גלי סינוס/משולש/רעש + מעטפות ADSR + פילטרים (one‑pole, state‑variable bandpass).
- מוזיקה: פרוגרסיית אקורדים עם pad/bass/arp/bell; לופ חלק ב‑wrap‑add (הזנב שחורג
  מסוף הלופ מקופל בחזרה לתחילתו) + בדיקת רציפות אוטומטית בנקודת החיבור.
- מוזיקה נשארת ב‑MP3 (תאימות iOS/AVFoundation; OGG לא מתנגן שם).
