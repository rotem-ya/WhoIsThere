# שיגור לשתי החנויות בריצה אחת (Codemagic)

הוגדר workflow מאוחד ב-`codemagic.yaml` בשם **`stores-release`**. בריצה **אחת**
(על מכונת macOS) הוא בונה גם IPA וגם AAB, ומעלה אותם **בו-זמנית**:
- IPA → App Store / TestFlight
- AAB (חתום EA:3B) → Google Play (Internal testing)

**טריגר:** דחיפת תג `release-v*` (למשל `release-v1`) לענף ההשקה. אפשר גם Start
build ידני ב-Codemagic UI.

> נשאר גם `ios-testflight` (תג `ios-v*`) כגיבוי לתיקון iOS-בלבד. מסלול ה-AAB דרך
> GitHub Actions (`build-aab.yml`) עדיין קיים כגיבוי ידני.

---

## הצעד החד-פעמי היחיד שרק אתה יכול לעשות (~15 דקות)

זה המקבילה למפתח ה-ASC של אפל — Codemagic צריך **חשבון שירות (Service Account)
של Google Play** כדי להעלות בשמך.

### 1. יצירת חשבון שירות
1. Google Play Console → **Setup → API access**.
2. אם עוד לא מקושר פרויקט Google Cloud — לחץ **Link/Create project** ואשר.
3. תחת **Service accounts** → **Create new service account** → זה פותח את
   Google Cloud Console.
4. ב-Google Cloud: **Create Service Account** (שם למשל `codemagic-play`) →
   Done. אחר כך על החשבון שנוצר → **Keys → Add Key → Create new key → JSON** →
   יורד קובץ JSON. **שמור אותו.**

### 2. הרשאות ב-Play Console
1. חזרה ל-Play Console → **API access** → ליד חשבון השירות החדש → **Manage
   Play permissions** (או Users & permissions → Invite → הדבק את מייל חשבון
   השירות).
2. תן לו לפחות **Release to testing tracks** על האפליקציה (או Admin לאפליקציה
   הזו). שמור.

### 3. הזנה ל-Codemagic
1. Codemagic → האפליקציה → **Environment variables**.
2. Group: **`google_play`** (בדיוק השם הזה).
3. Variable name: **`GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`**
   Value: **כל תוכן ה-JSON** (הדבק את הקובץ כולו). סמן **Secure**. Add.

זהו. מכאן זה אוטומטי.

---

## איך משגרים גרסה (שתי החנויות ביחד)

```bash
git tag release-v1 origin/claude/whoishere-visual-sound-rjcdzb
git push origin release-v1
```

Codemagic יבנה IPA + AAB באותה ריצה, יאמת חתימת EA:3B ל-AAB, ויעלה:
- ל-**TestFlight** (בלי submit ל-review)
- ל-**Google Play → Internal testing** (בלי המתנת review). testers פנימיים
  יקבלו את שתי הגרסאות מיד.

- **לשנות מסלול:** ב-`codemagic.yaml` תחת `stores-release` → `vars.PLAY_TRACK`
  (`internal` / `alpha` / `beta` / `production`).
- **versionCode:** נגזר מ-`PROJECT_BUILD_NUMBER + 100` — תמיד גבוה מ-40 (הקוד
  הכי גבוה שנבנה ב-GitHub Actions), כך שאין התנגשות "קוד כפול".
- **חתימה:** משתמש באותו מפתח EA:3B (מפוענח מ-`android/app/upload_keystore.b64`)
  עם שלב אימות שנכשל אם החתימה שגויה — אתה מוגן.

## חשוב — הפעם הראשונה בכל track
Google Play API יכול לפרסם רק לאפליקציה שכבר **קיימת** בחנות (שלנו קיימת, v1.0
אושרה). אם track מסוים מעולם לא קיבל בילד ידני, ייתכן שהעלאה ראשונה אליו דרך API
תיחסם — במקרה כזה מעלים AAB אחד ידנית ל-track, ומשם ה-API עובד. ל-Internal testing
בדרך כלל אין בעיה כי כבר יש שם בילדים.

## מסלול GitHub Actions (עדיין קיים, לא הוסר)
`build-aab.yml` ממשיך לעבוד — הוא בונה AAB ומעלה כ-artifact להורדה+העלאה ידנית.
נשאר כגיבוי; המסלול המומלץ קדימה הוא Codemagic האוטומטי.
