# פרומפט ל-cowork — הגשת v1.1.1 לגוגל ולאפל (סבב סופי)

עבוד עם רותם **שלב-שלב, לפי הסדר**. לכל פעולה בממשק — הסבר מה ללחוץ, המתן לאישור/צילום, סמן ✔, המשך. **הענף היחיד לבנייה: `claude/qa-launch-prep-EXqLn`.**

## מצב נוכחי (מה כבר סגור)
- ✅ **חתימת iOS פתורה** — בילד Codemagic #68 עבר (aps-environment=production), 1.1.1 build 1068 עלה ל-TestFlight. הפרופיל נוצר אוטומטית בכל בילד (אין יותר בעיות signing).
- ✅ **Push/APNs מוגדר** (ה-.p8 הועלה ל-Firebase, ה-App ID עם Push).
- ✅ **v1.1.0 אושרה** בשתי החנויות.
- ⚠️ **צריך בילדים טריים (build 1.1.1+64, label `r6`):** ה-HEAD העדכני נמצא בענף `claude/rematch-bug-investigation-az4n6h` (commit `024584e`) וכולל, מעבר ל-1068:
  - **27 סקינים מוטמעים** ל-assets: 16 גב-כרטיסיות (כולל דגל ישראל) + 11 רקעי-לוח — טעינה מיידית, בלי קריאת ענן.
  - **הוסרו לגמרי מהחנות: מסגרות אווטר + צבעי שם.** נשארו: אווטרים · אפקטי ניצחון · גב כרטיס · רקע לוח. שמות מוצגים רגיל, אווטרים ללא טבעת.
  - **אפקט ניצחון חדש "מופע זיקוקים"** (premium 1000).
  - **תיקון קריטי:** מקלדת הניחוש נסגרה באמצע הקלדה בכל חשיפת משבצת — תוקן (סגירה רק במעבר תמונה אמיתי).
  - `flutter analyze` נקי.

---

## שלב 0 — סנכרון ענף ההשקה (חובה לפני בנייה)
ה-AAB וה-iOS נבנים רק מ-`claude/qa-launch-prep-EXqLn`, אבל ה-HEAD העדכני בענף `claude/rematch-bug-investigation-az4n6h`. הבא את ענף ההשקה ל-HEAD העדכני (fast-forward), מהמחשב של רותם:
```
git fetch origin
git push origin origin/claude/rematch-bug-investigation-az4n6h:claude/qa-launch-prep-EXqLn
```
- [ ] אם ה-push נדחה (לא fast-forward): `git checkout claude/qa-launch-prep-EXqLn && git merge --ff-only origin/claude/rematch-bug-investigation-az4n6h && git push`. אם עדיין נדחה — למסור לקלוד, לא לכפות.
- [ ] ודא ש-`git log -1 origin/claude/qa-launch-prep-EXqLn` מציג את commit `024584e` ("fix: guess keyboard closing…").

## שלב 1 — בילד Android (AAB)
מרקר ה-AAB כבר עודכן (r5/r6). ה-push בשלב 0 לענף ההשקה **יפעיל את הבילד אוטומטית** (הטריגר הוא שינוי `aab-release.txt` על `qa-launch-prep-EXqLn`).
- [ ] GitHub → Actions → **Build AAB (Google Play)** → הריצה האחרונה על `qa-launch-prep-EXqLn` → המתן לירוק (~10 דק').
- [ ] בסוף — הורד את ה-artifact **`app-release.aab`**.
- [ ] אם לא נדלק/נכשל: הרץ ידנית Actions → Build AAB → Run workflow → branch `qa-launch-prep-EXqLn`, `build_name=1.1.1`.

## שלב 2 — בילד iOS (Codemagic → TestFlight)
מהמחשב של רותם (דחיפת תג, **אחרי** שלב 0):
```
git fetch origin && git tag ios-v10 origin/claude/qa-launch-prep-EXqLn && git push origin ios-v10
```
- [ ] Codemagic בונה IPA חתום ומעלה אוטומטית ל-TestFlight (~15 דק'). Version 1.1.1, build ~1070.
- [ ] ודא ש-Codemagic רץ על הקומיט `024584e`.

## שלב 3 — Google Play Console (com.whoisthere.app)
- [ ] Testing → **Closed testing (Alpha)** → Create new release.
- [ ] העלה את `app-release.aab` (versionCode יעלה אוטומטית מעל 25).
- [ ] **מה חדש** — הדבק את הטקסט מ"הערות גרסה" למטה.
- [ ] Countries: ללא EU-27 (כמו קודם). Save → Review → **Start rollout to Closed testing**.

## שלב 4 — App Store Connect (Apple ID 6776076758)
- [ ] המתן ש-build 1069 יסיים "Processing" ב-TestFlight (~10-30 דק').
- [ ] App Store tab → הגרסה 1.1.1 → **Build** → בחר 1069.
- [ ] **What's New in This Version** — הדבק את הטקסט למטה.
- [ ] אם 1.1.1 עדיין לא נוצרה כגרסה: **+ Version** → 1.1.1 → מלא Build + What's New.
- [ ] **Add for Review → Submit**. (Export compliance: אין הצפנה חריגה → "No".)

## שלב 5 — אימות כתובות (למנוע דחייה + אזהרת AdMob)
- [ ] Play: Store settings → Website = `https://whoisthere-380fa.web.app` · Privacy = `.../privacy/`
- [ ] ASC: Privacy Policy URL = `.../privacy/` · Support URL = `.../support/`
- [ ] AdMob → app-ads.txt → "בדוק עדכונים" (סריקה עד 24ש'; ב-Closed Testing עלול להישאר עד Open — לא חוסם).

---

## הערות גרסה — "מה חדש" (להדביק בשתי החנויות)
```
✨ עיצובי גב-כרטיסיות חדשים ומרהיבים — אוסף שלם של דוגמאות מפוארות
🎨 חנות מתחדשת עם פריטי קוסמטיקה נוספים
⚡ טעינה מהירה בהרבה וחוויה חלקה יותר
🔔 התראות להזמנות ובקשות חברות
🐛 תיקוני יציבות ושיפורי ביצועים
```

## אחרי אישור — למסור לקלוד
- מספרי הבילד שהתקבלו (Play versionCode / iOS build).
- כל דחייה/הערה מהחנויות (טקסט מלא) — קלוד יתקן ויחזיר בילד.
- אם רוצים מעבר מ-Closed ל-Open/Production — לומר לקלוד לתאם.
