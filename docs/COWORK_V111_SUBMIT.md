# פרומפט ל-cowork — הגשת v1.1.1 לגוגל ולאפל (סבב סופי)

עבוד עם רותם **שלב-שלב, לפי הסדר**. לכל פעולה בממשק — הסבר מה ללחוץ, המתן לאישור/צילום, סמן ✔, המשך. **הענף היחיד לבנייה: `claude/qa-launch-prep-EXqLn`.**

## מצב נוכחי (מה כבר סגור)
- ✅ **חתימת iOS פתורה** — בילד Codemagic #68 עבר (aps-environment=production), 1.1.1 build 1068 עלה ל-TestFlight. הפרופיל נוצר אוטומטית בכל בילד (אין יותר בעיות signing).
- ✅ **Push/APNs מוגדר** (ה-.p8 הועלה ל-Firebase, ה-App ID עם Push).
- ✅ **v1.1.0 אושרה** בשתי החנויות.
- ⚠️ **צריך בילדים טריים:** build 1068 נבנה **לפני** כל עבודת הסקינים המוטמעים. ה-HEAD הנוכחי כולל: 30 גב-כרטיסיות מוטמעים (טעינה מיידית), חלוקת תמונה על הלוח, מטמון-דיסק, סקין-מארח-לכולם, ושיפורי אדמין. לכן בונים מחדש את שני הצדדים.

---

## שלב 1 — בילד Android (AAB)
**קלוד כבר הדליק אותו** (דחיפת `.github/aab-release.txt`). 
- [ ] GitHub → Actions → **Build AAB (Google Play)** → הריצה האחרונה → המתן לירוק (~10 דק').
- [ ] בסוף — הורד את ה-artifact **`app-release.aab`**.
- [ ] אם נכשל: הרץ ידנית Actions → Build AAB → Run workflow → `build_name=1.1.1`.

## שלב 2 — בילד iOS (Codemagic → TestFlight)
מהמחשב של רותם (דחיפת תג):
```
git fetch origin && git tag ios-v9 origin/claude/qa-launch-prep-EXqLn && git push origin ios-v9
```
- [ ] Codemagic בונה IPA חתום ומעלה אוטומטית ל-TestFlight (~15 דק'). Version 1.1.1, build 1069.
- [ ] אם קלוד כבר דחף `ios-v9` — דלג, רק ודא ש-Codemagic רץ.

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
