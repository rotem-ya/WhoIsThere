# פרומפט ל-cowork — EMERGENCY: הגשת 1.3.2 (תיקון דחוף) לשתי החנויות

זו הגשה **דחופה**. הגרסה החיה כרגע (1.3.1) בשתי החנויות, פתוחה לציבור הרחב, נגועה בבאג חמור: פאנל ניחוש-האותיות בתורות (פיצ'ר חדש ב-1.3.1) מכווץ את תמונת המשחק כמעט לגמרי במשחקי חברים. התיקון כבר בקוד (`kLetterTurnFeatureEnabled=false`, commit `9911b4f`), משבית את הפאנל לגמרי בכל המשחקים חוץ ממשחק האותיות הנפרד (שלא נפגע כלל). עבוד עם רותם **שלב-שלב**, אבל **מהר** — זו לא הגשת פיצ'ר רגילה, המטרה היא לצמצם את זמן החשיפה לבאג.

## מה כבר קרה אוטומטית (לוודא בלבד)
- [ ] `.github/aab-release.txt` עודכן ונדחף לענף `claude/whothere-v111-launch-iqkbq2` — זה כבר **אמור** להפעיל בניית AAB אוטומטית (build-name 1.3.2). ודא ב-Actions → "Build AAB (Google Play)" שרצה ריצה חדשה על הקומיט `9911b4f` (או מאוחר יותר) והסתיימה בהצלחה.
- [ ] `build-apk.yml` (בדיקה מהירה בלבד, לא לחנויות) גם רץ אוטומטית על אותו קומיט.

## שלב 1 — תג iOS (חובה, ידני — קלוד לא הצליח לדחוף תג)
קלוד יצר מקומית תג `ios-v16` על קומיט `9911b4f` אבל לא הצליח לדחוף אותו (403 — אין הרשאת push לתגיות מהסביבה שלו). דרוש מרותם:
```bash
git fetch origin claude/whothere-v111-launch-iqkbq2
git tag ios-v16 9911b4f
git push origin ios-v16
```
זה מפעיל אוטומטית את Codemagic (workflow `ios-testflight`) → בונה IPA חתום עם `--build-name=1.3.2` → מעלה ל-TestFlight (~15-25 דק'). לחלופין: Codemagic UI → Start build ידני על ה-workflow הזה, מסניף `claude/whothere-v111-launch-iqkbq2`, קומיט `9911b4f`.

## שלב 2 — Google Play Console (com.whoisthere.app)
1. המתן שריצת ה-AAB (שלב "מה כבר קרה") תסתיים. הורד את ה-artifact `app-release.aab` (versionCode = מספר הריצה).
2. Play Console → Production (או הערוץ שבו 1.3.1 חי כרגע) → **Create new release**.
3. העלה את ה-AAB. **Release notes:**
   ```
   🐛 תיקון דחוף: באג תצוגה שגרם לתמונת המשחק להיות קטנה מדי במשחקי חברים
   ```
4. Save → Review → **Start rollout**. Play בדרך כלל מאשר עדכונים תוך שעות בודדות — אין צורך בבקשת האצה מיוחדת.

## שלב 3 — App Store Connect (Apple ID 6776076758) + בקשת סקירה מזורזת
1. המתן שהבילד של 1.3.2 יסיים "Processing" ב-TestFlight (~10-30 דק' אחרי שלב 1).
2. App Store tab → **+ Version** → `1.3.2`.
3. **Build** → בחר את בילד 1.3.2.
4. **What's New in This Version:**
   ```
   🐛 תיקון דחוף: באג תצוגה שגרם לתמונת המשחק להיות קטנה מדי במשחקי חברים
   ```
5. **Add for Review → Submit.**
6. **קריטי — בקש Expedited Review:** סקירה רגילה של אפל לוקחת 1-3 ימים; יש לבאג הזה חשיפה לציבור הרחב **עכשיו**, אז יש לבקש סקירה מזורזת:
   - הדרך הרשמית: https://developer.apple.com/contact/app-store/?topic=expedite (טופס של Apple, דורש התחברות עם Apple ID של המפתח).
   - למלא: שם האפליקציה (`מה בתמונה?`), ה-Apple ID (6776076758), ותיאור קצר של הבעיה — משהו כמו: "Critical UI bug in our live 1.3.1 release makes the game image nearly invisible during a specific game mode. Fix submitted as 1.3.2, requesting expedited review to minimize user impact."
   - אפל בדרך כלל עונים תוך שעות ומאשרים תוך יום, לעומת 1-3 ימים רגיל.

## שלב 4 — אימותים
- Play: Store settings → Website/Privacy כמו קודם (לא השתנה).
- ASC: Privacy Policy URL / Support URL כמו קודם (לא השתנה).

## אחרי הביצוע — למסור לי
- מספרי הבילד שהתקבלו (Play versionCode / iOS build number).
- האם בקשת ה-Expedited Review אושרה, ותוך כמה זמן.
- כל דחייה/הערה מהחנויות — אתקן ואחזיר בילד.
