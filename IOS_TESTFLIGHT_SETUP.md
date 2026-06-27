# התקנה על אייפון — מדריך צעד-אחר-צעד (לצורכי בדיקות)

המטרה: לבנות את WhoIsThere ולהתקין אותו על האייפון שלך לבדיקה, **בלי Mac**,
דרך שירות הבנייה Codemagic + TestFlight של אפל.

מזהה האפליקציה (Bundle ID): **`com.rotem.whoisthere`**
פרויקט Firebase: **whoisthere-380fa**

יש 6 שלבים. עשה אותם לפי הסדר. כל שלב כולל **קישור ישיר** ומה ללחוץ.

---

## שלב 1 — צור את ה-App ID אצל אפל
🔗 פתח: https://developer.apple.com/account/resources/identifiers/list
(התחבר עם ה-Apple ID של חשבון המפתח שלך)

1. לחץ על כפתור **➕** (ליד הכותרת "Identifiers").
2. בחר **App IDs** → **Continue** → בחר **App** → **Continue**.
3. **Description**: כתוב `WhoIsThere`.
4. **Bundle ID**: בחר **Explicit** והדבק בדיוק: `com.rotem.whoisthere`
5. לחץ **Continue** → **Register**.

> אם ה-Bundle ID כבר קיים ברשימה — מעולה, דלג לשלב 2.

---

## שלב 2 — צור את האפליקציה ב-App Store Connect
🔗 פתח: https://appstoreconnect.apple.com/apps

1. לחץ על **➕** (שמאל למעלה) → **New App**.
2. מלא:
   - **Platforms**: סמן **iOS**
   - **Name**: `מה בתמונה?` (או `WhoIsThere`)
   - **Primary Language**: Hebrew
   - **Bundle ID**: בחר מהרשימה את `com.rotem.whoisthere`
   - **SKU**: כתוב משהו כמו `whoisthere001` (מזהה פנימי, לא משנה מה)
   - **User Access**: Full Access
3. לחץ **Create**.

> זהו לגבי App Store Connect — לבדיקות פנימיות לא צריך צילומי מסך/תיאור.

---

## שלב 3 — צור מפתח API (קובץ .p8) — זה מה ש-Codemagic צריך
🔗 פתח: https://appstoreconnect.apple.com/access/integrations/api

1. (אם מבקש) לחץ **Request Access** / אשר גישה ל-API. אם זו הפעם הראשונה.
2. תחת **Team Keys** לחץ **➕** (Generate API Key / Add).
3. **Name**: `Codemagic`
4. **Access**: בחר **App Manager**.
5. לחץ **Generate**.
6. בשורה שנוצרה לחץ **Download API Key** → יורד קובץ בשם `AuthKey_XXXXXX.p8`.
   ⚠️ **אפשר להוריד אותו רק פעם אחת — שמור אותו טוב.**
7. רשום לעצמך 2 דברים מהמסך הזה:
   - **Issuer ID** (מחרוזת ארוכה למעלה בעמוד)
   - **Key ID** (המזהה של המפתח שיצרת)

---

## שלב 4 — חבר את Codemagic לריפו
🔗 פתח: https://codemagic.io/signup

1. לחץ **Sign up with GitHub** והתחבר עם חשבון ה-GitHub שלך.
2. אשר ל-Codemagic גישה לריפו **rotem-ya/WhoIsThere** (אפשר לבחור "Only select repositories").
3. אחרי הכניסה: 🔗 https://codemagic.io/apps → לחץ **Add application**.
4. בחר **GitHub** → בחר את הריפו **rotem-ya/WhoIsThere** → לחץ **Finish: Add application**.
   - Codemagic יזהה אוטומטית את הקובץ `codemagic.yaml` שכבר בריפו.

---

## שלב 5 — הוסף ל-Codemagic את מפתח ה-.p8 (חד-פעמי)
🔗 פתח: https://codemagic.io/teams
(או: בפינה למעלה לחץ על שם המשתמש/הצוות → **Integrations**)

1. מצא **App Store Connect** ברשימת ה-Integrations → לחץ **Manage keys** / **Add key**.
2. מלא:
   - **App Store Connect API key name**: הקלד בדיוק 👉 `Apple_Key_Trivia`
     ⚠️ חייב להיות **בדיוק** השם הזה — ככה זה כתוב בקובץ `codemagic.yaml`
     (`integrations: app_store_connect: Apple_Key_Trivia`). שם אחר → הבנייה תיכשל "key not found".
   - **Issuer ID**: הדבק את מה שרשמת בשלב 3.
   - **Key ID**: הדבק את מה שרשמת בשלב 3.
   - **API key**: העלה את קובץ ה-`AuthKey_XXXXXX.p8` מהשלב 3.
3. לחץ **Save**.

---

## שלב 6 — הרץ בנייה והתקן באייפון
1. 🔗 פתח https://codemagic.io/apps → לחץ על **WhoIsThere**.
2. למעלה בחר את ה-workflow **`WhoIsThere iOS — TestFlight`** → לחץ **Start new build**.
3. חכה ~15–25 דקות. בסיום, הבילד נשלח אוטומטית ל-TestFlight.
4. באייפון: התקן את אפליקציית **TestFlight**:
   🔗 https://apps.apple.com/app/testflight/id899247664
5. 🔗 חזור ל-https://appstoreconnect.apple.com/apps → האפליקציה שלך → לשונית **TestFlight** →
   תחת **Internal Testing** לחץ **➕** והוסף את עצמך (המייל של ה-Apple ID שלך) כבודק.
6. פתח את אפליקציית **TestFlight** באייפון → תראה את "מה בתמונה?" → לחץ **Install**. 🎉

---

## מה יעבוד עכשיו / מה לא
- ✅ **המשחק המלא במצב אורח** — נכנסים ומשחקים בלי התחברות.
- 🔶 **כניסה עם Google / Apple** — עדיין לא מוגדרת (דורש הגדרות נוספות בקונסולות).
  לבדיקת המשחק זה לא נדרש. כשתרצה להפעיל אותן — תגיד לי ואדריך/אשלים בקוד.

## נתקעת?
תגיד לי **באיזה שלב ומספר** נתקעת, ומה אתה רואה על המסך — ואכוון אותך נקודתית.
