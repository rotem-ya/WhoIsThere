# ✅ הצ'קליסט המרכזי — עובדים לפי הסדר, בקצב של רותם

עודכן: 2026-07-05. כל שלב מסומן מי מבצע: 🤖 = אני (סשן), 👤 = רותם, 🖥️ = cowork, 🎛️ = אדמין.
**חוקים:** שלב אחד בכל פעם. לא עוברים הלאה לפני שהשלב אומת. רותם נותן "המשך" בין שלבים.

## החלטת תשתית (התקבלה): Firebase Hosting מחליף את GitHub Pages
Firebase Hosting (חינם ב-Spark: 10GB אחסון, 360MB/יום תעבורה — הדפים שלנו שוקלים KB בודדים) עדיף על שני ה-GitHub Pages:
- **מנותק לגמרי מנראות הריפו** — אפשר להפוך לפרטי בלי שום תלות.
- **שליטה בשורש הדומיין** → `app-ads.txt` ב-`https://whoisthere-380fa.web.app/app-ads.txt` (פותר את דרישת AdMob בלי ריפו חדש).
- **בונוס עתידי:** App Links/Universal Links מאומתים (assetlinks.json / apple-app-site-association) — בלתי אפשרי ב-github.io.
- **פריסה אוטומטית מ-CI** עם ה-`FIREBASE_SERVICE_ACCOUNT` שכבר קיים ועובד — מייתר את ה-PAGES_SYNC_TOKEN השבור.
- מה **לא** מעבירים לשם: קובץ ה-APK ל-QA (100MB יחסלו את מכסת היום אחרי 3 הורדות) — לזה Firebase App Distribution (גם חינם).
- `apps-share-pages` נשאר כפי שהוא כ-mirror ישן — קישורים שכבר שותפו ממשיכים לעבוד. בלי תחזוקה.

---

## שלב 1 — 💰 חשבון AdMob מוכן לקבל כסף · 👤
בלי זה אין תשלום גם כשהמודעות האמיתיות יעלו (הן כבר בקוד לגרסה הבאה):
1. admob.google.com → Payments → להשלים פרטי תשלום + פרטי מס.
2. לוודא שאין התראות אדומות בראש הדשבורד (אימות כתובת ב-PIN מגיע בדואר — לוקח שבועות, להתחיל עכשיו).
- **אימות:** במסך Payments אין פעולות ממתינות (מלבד PIN אם טרם הגיע).

## שלב 2 — 🌐 הקמת Firebase Hosting והעברת כל הדפים · 🤖 — ✅ בוצע (2026-07-05)
האתר חי: https://whoisthere-380fa.web.app — כל הדפים + app-ads.txt + seed מחזירים 200; פריסה אוטומטית עובדת (run #1 ירוק); הקוד והמניפסט עודכנו.
1. הוספת `hosting` ל-`firebase.json` + תיקיית `public/` עם: privacy, support, friend, join, download, `app-ads.txt`, seed לאדמין, ודף בית קצר.
2. workflow פריסה אוטומטי (על שינוי ב-public/ ב-main) עם ה-service account הקיים.
3. עדכון הקוד: `friendPageUrl`/`joinPageUrl` → `whoisthere-380fa.web.app`, הוספת ה-host החדש ל-deep-link handler ול-AndroidManifest (שומרים זיהוי של כל ה-hosts הישנים).
- **אימות:** כל הכתובות החדשות 200 + קישור friend חדש פותח את האפליקציה.
- ⚠️ ייתכן צורך חד-פעמי 👤: אם ל-service account חסרה הרשאת Hosting Admin — הוספה ב-IAM (אדריך בזמן אמת).

## שלב 3 — 🏪 עדכון כתובות בחנויות (פעם אחת, ליעד הסופי) · 🖥️ cowork
אחרי ששלב 2 חי: Play (Privacy policy + אתר מפתח) ו-ASC (Privacy/Support/Marketing) → כתובות ה-web.app. אתר המפתח = `https://whoisthere-380fa.web.app` (שם יושב app-ads.txt).
- **אימות:** AdMob → Apps → "Verify app-ads.txt" מזהה את הקובץ (עד 24ש׳).

## שלב 4 — 📊 Firebase Analytics · 🤖 — ✅ בוצע (2026-07-05)
firebase_analytics ^10.8 + AnalyticsService; אירועים: game_start/game_win (places/heat/letters, solo), invite_sent (friend_code/room), ad_rewarded_watched (4 placements), feedback_sent, store_view. נותר לאמת ב-DebugView על מכשיר.
`firebase_analytics` + ~10 אירועים: game_start/game_win (לפי מצב), invite_sent/accepted, ad_rewarded_watched, store_view, purchase_coins_spent, feedback_sent. בלי דאטה — כל החלטות הניהול עיוורות.
- **אימות:** אירועים ב-DebugView.

## שלב 5 — 🚀 הגרסה הבאה (v1.1.1) — "גרסת ההכנסות" · 🤖 בילד, 🖥️ הגשה — ⏳ מוכן, ממתין לאישור v1.1.0
הגרסה קודמה ל-1.1.1+61 בכל הקבצים; כל התוכן בענף ההשקה. כשה-v1.1.0 מאושרת: marker ל-AAB + תג ios-v4.
כבר בקוד ומחכה: מודעות אמיתיות, SKAdNetwork ל-iOS, פרומפט דירוג, קישור חבר עמיד-לפרטי; יתווספו: כתובות web.app (שלב 2) + Analytics (שלב 4).
טריגר: אחרי ש-v1.1.0 מאושרת בשתי החנויות. AAB דרך marker; iOS דרך תג `ios-v4`.
- **אימות:** מודעות אמיתיות מופיעות במכשיר; הכנסות מתחילות להיספר ב-AdMob תוך ~48ש׳.

## שלב 6 — 🔒 המעבר לריפו פרטי · 🖥️ cowork
אחרי ש-v1.1.1 (עם הקישורים החדשים) באוויר. לפי `docs/GO_PRIVATE_CHECKLIST.md` + `docs/COWORK_GO_PRIVATE_PROMPT.md` — בזכות שלב 2 אין יותר תלות בשום Pages.
- **אימות:** הריפו פרטי; Actions ו-Codemagic עובדים; כל הדפים חיים.

## שלב 7 — 🔑 סיבוב מפתחות · 👤+🖥️
1. איפוס upload key ב-Play (EA:3B היה חשוף) → keystore חדש → Secrets → הסרת המוטמע מ-build-aab.yml (וגם 25:C3 מ-build-apk.yml).
2. ה-PAGES_SYNC_TOKEN — מתייתר אחרי שלב 2 (אפשר למחוק את ה-workflow).
- **אימות:** בילד AAB ירוק חתום במפתח החדש.

## שלב 8 — 🎛️ תיבת משוב באדמין · 🎛️ אדמין
הדאטה כבר זורם (`feedback/{id}`, `crash_reports/{id}`, read:isAdmin). מסך Inbox: רשימה ממוינת, סימון "טופל", מונה חדשים.

## שלב 9 — 💸 מונטיזציה שלב ב' · 🤖
לפי `docs/GROWTH_AND_OPS_IDEAS.md`: rewarded נוספים (הכפלת פרס יומי, רמז תמורת צפייה, מטבעות במסך הפסד) → IAP "הסר פרסומות" → חבילות מטבעות.

## שלב 10 — 🔔 פוש להזמנות · 🤖 (דורש Blaze 👤)
ענף `claude/push-invites` כבר קיים. שדרוג ל-Blaze (חינם בפועל בשימוש שלנו) + APNs key. ה-retention loop החזק ביותר.

---
### תיקוני QA מבדיקת מכשיר (2026-07-05 ערב) — שלושתם בענף ההשקה
1. ✅ **כפתור ביטול הקלדה בניחוש** — קיים (מומש מוקדם יותר היום: "✕ ביטול" בראש חלון הניחוש).
2. ✅ **המקלדת נעלמת באמצע ניחוש אחרי ~20ש׳** — בוטל: הוסר טיימר הסגירה האוטומטית; החלון נסגר רק בשליחה / ביטול / מעבר תמונה.
3. ✅ **מעבר תמונה מבטל הקלדה + חשיפה מסונכרנת לכולם** — קיים (סגירת overlay במעבר סבב, guard `stale_image`, מסך ביניים 4ש׳ שדוחה את החשיפה).
⚠️ **ה-APK הנכון לבדיקה:** `releases/download/qa-launch/app-release.apk` (ענף ההשקה). ה-`qa-latest` נבנה מ-main הישן — הלוג שנשלח תואם לבילד ישן (אין מסך ביניים, אין כפתור ביטול).

### מגרש חנייה (לא ממוספר — כשמתפנה)
משימות יומיות · לוקליזציה לאנגלית · Firebase App Distribution ל-QA · דוח שבועי אוטומטי · ניקוי חדרים ישנים · פוליש משחק האותיות (מהרשימה הדחויה) · Crashlytics
