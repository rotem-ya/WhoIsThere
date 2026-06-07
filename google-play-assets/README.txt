מדריך העלאה ל-Google Play Console — "מה בתמונה?" (WhoIsThere)
==============================================================

תוכן החבילה
-----------
google-play-assets/
├── texts/
│   ├── app_title.txt            ← שם האפליקציה (10/30 תווים)
│   ├── short_description.txt    ← תיאור קצר (64/80 תווים)
│   ├── full_description.txt     ← תיאור מלא (632/4000 תווים)
│   └── privacy_policy_url.txt   ← קישור מדיניות פרטיות
├── graphics/
│   ├── icon_512x512.png         ← אייקון 512×512 PNG (32-bit)
│   ├── feature_graphic_1024x500.png ← Feature graphic 1024×500 PNG
│   └── screenshots/
│       ├── phone_screenshot_1.png   (1080×1920)
│       ├── phone_screenshot_2.png   (1080×1920)
│       ├── phone_screenshot_3.png   (1080×1920)
│       └── phone_screenshot_4.png   (1080×1920)
└── README.txt                   ← הקובץ הזה

איפה להדביק כל פריט ב-Play Console
----------------------------------
Play Console → בחר את האפליקציה → Grow → Store presence → **Main store listing**

1) App name (שם האפליקציה)
   • הדבק את התוכן מ-texts/app_title.txt
   • מגבלה: 30 תווים.

2) Short description (תיאור קצר)
   • הדבק את התוכן מ-texts/short_description.txt
   • מגבלה: 80 תווים.

3) Full description (תיאור מלא)
   • הדבק את התוכן מ-texts/full_description.txt
   • מגבלה: 4000 תווים.

4) App icon (אייקון)
   • העלה graphics/icon_512x512.png
   • דרישה מדויקת: 512×512 פיקסל, PNG, עד 1MB.

5) Feature graphic (גרפיקת נושא)
   • העלה graphics/feature_graphic_1024x500.png
   • דרישה מדויקת: 1024×500 פיקסל, PNG/JPG.

6) Phone screenshots (צילומי מסך לטלפון)
   • העלה את 4 הקבצים מ-graphics/screenshots/
   • דרישה: לפחות 2 צילומים, 1080×1920 פיקסל (פורטרט). כאן יש 4.
   • הערה: אלה צילומי מוקאפ שיווקיים. מומלץ בהמשך להחליף/להוסיף
     צילומי מסך אמיתיים מהמכשיר (מסך בית, משחק, ניצחון, חנות, מפה).

7) Privacy policy URL (מדיניות פרטיות)
   • App content → Privacy policy → הדבק את הקישור מ-
     texts/privacy_policy_url.txt :
     https://rotem-ya.github.io/WhoIsThere/privacy.html
   • דרוש פעם אחת: הפעל GitHub Pages (Settings → Pages → Branch: main, Folder: /docs).

תזכורת מידות מדויקות
--------------------
• אייקון:           512 × 512 px  (PNG, < 1MB)
• Feature graphic:  1024 × 500 px (PNG)
• צילומי מסך טלפון:  1080 × 1920 px (PNG, פורטרט) — לפחות 2

מידע משלים להגשה (מתוך GOOGLE_PLAY_LISTING.md)
----------------------------------------------
• קטגוריה: משחקים → חידון/טריוויה (Trivia)
• מחיר: חינם (עם פרסומות — AdMob)
• Content rating: מלא שאלון IARC (ללא אלימות/מין/שפה/סמים; יש פרסומות).
• Data safety: נאספים שם, אימייל, User IDs, App interactions, Advertising ID.
• Target audience: 13+ (לא מיועד לילדים).
• אימייל תמיכה: askthekids.app@gmail.com
