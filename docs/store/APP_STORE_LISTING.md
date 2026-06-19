# App Store (iOS) — חומרי חנות + צ'קליסט הגשה ל-review

מסמך עבודה להעלאת **"מה בתמונה?"** ל-App Store. כל הטקסטים מוכנים להעתקה.
פרטים טכניים: Bundle ID `com.rotem.whoisthere` · גרסה `1.0.0` · Firebase `whoisthere-380fa` ·
בנייה: Codemagic workflow **`ios-testflight`** (ראה `IOS_TESTFLIGHT_SETUP.md` / `codemagic.yaml`).

> חלק מהשדות נכנסים ב-App Store Connect → **App Information** וחלק ב-**1.0 Prepare for Submission**.
> דירוג גיל ו-App Privacy הם שאלונים נפרדים שצריך למלא ידנית בקונסולה (הטבלאות כאן הן התשובות).

---

## 1. שם וטקסטים

**שם האפליקציה** (App Name, עד 30 תווים):
```
מה בתמונה?
```

**כותרת משנה** (Subtitle, עד 30 תווים):
```
משחק הניחושים המהיר
```

**טקסט קידום** (Promotional Text, עד 170 תווים — ניתן לעדכן בלי review חדש):
```
חדש: מצב "חי צומח דומם" עם 11 נושאים! שחקו מהר מול חברים ובוטים, טפסו ב-7 דרגות, ואספו את כל המקומות והנושאים במפת הגילויים.
```

**תיאור** (Description, עברית):
```
🧩 מה בתמונה? — משחק הניחושים המהיר שכולם מדברים עליו!

תמונה מתחבאת מאחורי לוח משבצות שנחשפות אחת-אחת. מי שמזהה ראשון — מנצח! ככל שתנחשו מוקדם יותר, כך תרוויחו יותר מטבעות וניקוד. אבל זהירות: ניחוש שגוי עולה לכם.

🎮 שני מצבי משחק:
• זיהוי מקומות בישראל — עשרות אתרים ונופים מרהיבים, מהכותל ועד מכתש רמון
• חי צומח דומם — מקצה מהיר על 11 נושאים: חיות, פרחים, דומם, ציפורים, כלי תחבורה, מקצועות, דגלים, כלי נגינה, פירות וירקות, בגדים וספורט

✨ מה מחכה לכם:
• משחק מהיר מול שחקנים אמיתיים ובוטים — או חדרים פרטיים מול חברים
• משחק חברים: כל משתתף בוחר נושא, והמארח קובע כמה סבבים יהיו
• כלכלת מטבעות: ארנק, חנות, ופרס יומי עם בונוס רצף
• כרטיסי פעולה שנפתחים ככל שמתקדמים: חסימת ניחוש, החשכת לוח, כרטיס עצור ועוד
• 7 דרגות שחקן — מ"עיוור" ועד "אגדה"
• מפת הגילויים — אספו את כל המקומות והנושאים שזיהיתם

🎯 קל ללמוד, קשה להניח מהיד. כמה מהר תזהו מה בתמונה?

הורידו עכשיו והתחילו לנחש!
```

**Description (English — for the en-US locale):**
```
🧩 What's in the Picture? — the fast guessing game everyone's talking about!

A picture hides behind a grid of tiles that reveal one by one. First to recognize it wins! The earlier you guess, the more coins and points you earn — but a wrong guess costs you.

🎮 Two game modes:
• Israeli places — dozens of stunning landmarks and landscapes
• Animal / Plant / Object — a fast heat across 11 topics: animals, flowers, objects, birds, vehicles, professions, flags, instruments, fruits & vegetables, clothing and sports

✨ What's inside:
• Quick match against real players and bots — or private rooms with friends
• Friends mode: every player picks a topic, the host sets how many rounds
• Coin economy: wallet, store, daily reward with streak bonus
• Action cards that unlock as you progress: guess-block, board blackout, stun and more
• 7 player ranks — from "Blind" to "Legend"
• Discovery map — collect every place and topic you identify

🎯 Easy to learn, hard to put down. How fast can you tell what's in the picture?
```

**מילות מפתח** (Keywords, עד 100 תווים, מופרד בפסיקים, בלי רווחים מיותרים):
```
נחש,תמונה,חידון,טריוויה,ניחושים,מקומות,ישראל,חיות,משחק,מולטיפלייר,חברים,מהיר
```

---

## 2. App Information (פרטים כלליים)

| שדה | ערך |
|-----|-----|
| Bundle ID | `com.rotem.whoisthere` |
| Primary Language | Hebrew |
| Category (Primary) | Games → **Trivia** |
| Category (Secondary) | Games → Word (אופציונלי) |
| Support URL | https://rotem-ya.github.io/WhoIsThere/ *(לוודא שקיים; אחרת דף תמיכה פשוט)* |
| Marketing URL (אופציונלי) | https://rotem-ya.github.io/WhoIsThere/ |
| Privacy Policy URL | https://rotem-ya.github.io/WhoIsThere/privacy.html |
| Copyright | 2026 Rotem |
| איש קשר ל-App Review | שם + טלפון + אימייל: askthekids.app@gmail.com |

**Sign-in for review:** האפליקציה ניתנת למשחק **במצב אורח** ללא התחברות → סמן ש-review לא צריך
חשבון דמו. (אם בכל זאת מבקשים — צרף הערה: "Play as guest, no login required.")

---

## 3. דירוג גיל (Age Rating — שאלון אפל)

ענה בכנות; עבור המשחק הזה הצפי:
- אלימות / תוכן מיני / שפה גסה / סמים / אימה → **None**
- **Simulated Gambling / הימורים מדומים** → **None** (מטבעות וירטואליים בלבד, ללא כסף אמיתי
  וללא המרה למזומן). אם אפל שואלת על "Contests" — אין.
- צפוי דירוג סופי: **4+** (אם בוחרים מחמיר בגלל אינטראקציה חברתית/פרסומות → ייתכן 9+/12+).

---

## 4. App Privacy ("Nutrition Label" — שאלון נפרד בקונסולה)

> ✅ **v1.0 = ללא פרסומות וללא tracking.** ב-`AdConstants.adsEnabled = false`, ו-`main.dart`
> כבר **לא מאתחל** את AdMob SDK כשהפרסומות כבויות — לכן **לא נאסף Advertising Identifier ואין
> tracking**, ולא נדרש ATT. (ראה §8 — כשמפעילים פרסומות בעתיד צריך לעדכן את הטבלה הזו + להוסיף ATT.)

**Data is collected — Yes.** מלא כך (Data linked to the user; **Used to Track = No בכל השורות**):

| Data Type | נאסף | מקושר למשתמש | Used to Track | מטרה (Purpose) |
|-----------|------|--------------|---------------|-----------------|
| Contact Info → Email Address | כן | כן | לא | App Functionality (חשבון/התחברות — Google/Apple sign-in) |
| User Content → Name (שם שחקן) | כן | כן | לא | App Functionality |
| Identifiers → User ID | כן | כן | לא | App Functionality (מצב משחק) |
| Usage Data → Product Interaction | כן | כן | לא | App Functionality |

- **Tracking:** None (אין שימוש ב-Advertising Identifier ב-v1.0).
- **Encryption in transit:** Yes
- **Data deletion request:** Yes — דרך אימייל התמיכה.

---

## 5. Export Compliance (בעת העלאת build)

- "Does your app use encryption?" → אם רק HTTPS/הצפנה סטנדרטית של מערכת ההפעלה → **Yes**, ואז
  **"exempt"** (uses standard encryption only). מומלץ להוסיף ל-`Info.plist`:
  `ITSAppUsesNonExemptEncryption = false` כדי לדלג על השאלה בכל העלאה. (לאמת/להוסיף — cowork.)

---

## 6. צילומי מסך (Screenshots — חובה, חסר)

נדרש **לפחות גודל אחד** של iPhone; מומלץ לספק את שני הגדלים:
| גודל | רזולוציה (portrait) | מכשיר לדוגמה | סטטוס |
|------|---------------------|---------------|-------|
| 6.7" | 1290 × 2796 | iPhone 15/16 Pro Max | ⬜ לצלם (3–6) |
| 6.5" | 1242 × 2688 | iPhone 11 Pro Max / XS Max | ⬜ לצלם (3–6) |

מסכים מומלצים לצילום: מסך בית, לוח משחק נחשף חלקית, רגע ניחוש/ניצחון, בחירת נושאים (חברים),
חנות הכרטיסים, מפת הגילויים. **אפל מקבלת את אותם צילומים לשני הגדלים** (יותאמו אוטומטית).
*(אפשר לצלם מ-TestFlight על מכשיר אמיתי אחרי שלב 1.)*

---

## 7. צ'קליסט הגשה ל-App Store Connect

- [ ] האפליקציה נוצרה ב-App Store Connect עם Bundle ID `com.rotem.whoisthere`
- [ ] Build עלה ל-TestFlight (Codemagic, שלב 1) ועבר Processing
- [ ] App Information: קטגוריה, שפה, URLs (סעיף 2)
- [ ] Privacy Policy URL חי ותקף (כולל AdMob+Firebase — לאמת `docs/privacy.html`)
- [ ] Description + Subtitle + Promotional + Keywords (סעיף 1) — עברית + en-US
- [ ] Age Rating (סעיף 3)
- [ ] App Privacy "Nutrition Label" (סעיף 4) — **v1.0: ATT לא נדרש** (אין tracking)
- [ ] Export Compliance / `ITSAppUsesNonExemptEncryption=false` (כבר ב-Info.plist)
- [ ] צילומי מסך 6.7"/6.5" (סעיף 6)
- [ ] בחר את ה-build, מלא "What to test"/"Notes for Review" (Play as guest)
- [ ] Submit for Review

---

## 8. כשמפעילים פרסומות בעתיד (לא ל-v1.0)
היום `AdConstants.adsEnabled = false` והקוד לא מאתחל AdMob. כשתרצו להדליק פרסומות:
1. החליפו את ה-test unit IDs ב-`lib/core/constants/ad_constants.dart` במזהים אמיתיים מ-AdMob,
   והחליפו את `GADApplicationIdentifier` ב-`ios/Runner/Info.plist` + ה-`APPLICATION_ID`
   ב-`android/app/src/main/AndroidManifest.xml` ל-App ID האמיתי.
2. `adsEnabled = true` (אז ה-SDK יאותחל ובאנרים/rewarded יחזרו).
3. **הוסיפו ATT ל-iOS**: `NSUserTrackingUsageDescription` ב-Info.plist + בקשת הרשאה
   (`AppTrackingTransparency`) לפני אתחול AdMob.
4. עדכנו את **App Privacy** (אפל) ל-"Advertising Identifier / Used to Track = Yes" ואת
   **Data safety** (Google) ל-"shares Advertising ID" — אחרת תהיה אי-התאמה ודחייה.

---

## דורש ממך (אדם — לא ניתן לאוטומציה)
- צילומי מסך אמיתיים מהמכשיר (אחרי TestFlight).
- מילוי שאלוני Age Rating + App Privacy בקונסולת App Store Connect (התשובות מוכנות כאן).
- החלטות: שם איש קשר + טלפון ל-App Review; קטגוריה משנית; מדינות זמינות.
