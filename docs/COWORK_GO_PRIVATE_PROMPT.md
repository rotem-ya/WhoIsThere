# פרומפט ל-cowork — ביצוע המעבר לריפו פרטי (2026-07-05)

העתק את הטקסט שמתחת לקו לצ'אט של cowork.

---

אתה מבצע את **המעבר של הריפו `rotem-ya/whoisthere` לפרטי**. כל התשתית כבר הוכנה ואומתה — כל הדפים הציבוריים וה-seed לאדמין חיים ב-`apps-share-pages` (שנשאר ציבורי), והקוד כבר עודכן. אתה מבצע רק את פעולות הקונסולות ואת ההפיכה עצמה, **בסדר הזה בדיוק**. המסמך המלא: `docs/GO_PRIVATE_CHECKLIST.md` בענף `claude/qa-launch-prep-EXqLn`.

## שלב 0 — אימות מקדים (2 דקות)
פתח בדפדפן וודא שכל אלה נטענים (200):
- https://rotem-ya.github.io/apps-share-pages/whoisthere/privacy/
- https://rotem-ya.github.io/apps-share-pages/whoisthere/support/
- https://rotem-ya.github.io/apps-share-pages/whoisthere/friend/?code=TEST12
- https://rotem-ya.github.io/apps-share-pages/whoisthere/join/?code=ABCDEF
- https://rotem-ya.github.io/apps-share-pages/whoisthere/content/content_catalog_seed.json

אם משהו לא נטען — עצור ודווח. (נבדקו ב-2026-07-05 — הכל 200.)

## שלב 1 — עדכון התצהירים בחנויות
### Play Console (מה בתמונה? · com.whoisthere.app)
1. Policy → App content → **Privacy policy** → החלף ל:
   `https://rotem-ya.github.io/apps-share-pages/whoisthere/privacy/` → Save.
2. אם יש שדות נוספים שמצביעים על `rotem-ya.github.io/WhoIsThere/...` (Store listing → contact/website) — החלף לאותו דומיין חדש (support/ לעמוד תמיכה).

### App Store Connect (מה בתמונה? · Apple ID 6776076758)
App Information (רמת האפליקציה, לא הגרסה):
- **Privacy Policy URL** → `https://rotem-ya.github.io/apps-share-pages/whoisthere/privacy/`
- **Support URL** → `https://rotem-ya.github.io/apps-share-pages/whoisthere/support/`
- **Marketing URL** (אם מולא) → `https://rotem-ya.github.io/apps-share-pages/whoisthere/`

⚠️ v1.1.0 (build 1061) נמצא **Waiting for Review**. עדכון App Information בדרך כלל נשמר מיד גם כשיש גרסה בביקורת. אם הממשק מסרב לשמור בגלל הביקורת — **עצור כאן, אל תהפוך לפרטי**, וחזור לשלב הזה מיד אחרי שהביקורת תסתיים.

## שלב 2 — Codemagic
Codemagic → Teams/Personal → Integrations → **GitHub**: ודא שההרשאה כוללת **private repositories** (אם החיבור הוא GitHub App — שהאפליקציה מותקנת עם גישה ל-whoisthere). אם אין ודאות — אפשר להשאיר ולבדוק בשלב 4; כשל fetch = לחדש הרשאה.

## שלב 3 — מיזוג עדכוני התשתית ל-main
מהמחשב (או PR רגיל):
```
git fetch origin claude/qa-launch-prep-EXqLn main
git checkout main && git pull
git checkout origin/claude/qa-launch-prep-EXqLn -- .github/workflows/sync-join-page.yml docs/GO_PRIVATE_CHECKLIST.md
git commit -m "infra: sync workflow covers all public pages + go-private checklist"
git push origin main
```
(זה רק ה-workflow והצ'קליסט — לא קוד אפליקציה. קוד האפליקציה נשאר בענף ההשקה כרגיל.)

## שלב 4 — ההפיכה לפרטי
GitHub → `rotem-ya/whoisthere` → Settings → General → Danger Zone → **Change repository visibility → Make private** (הקלד את שם הריפו לאישור).

## שלב 5 — בדיקות מיד אחרי
1. הדפים משלב 0 עדיין נטענים (הם ב-apps-share-pages — לא אמורים להיות מושפעים).
2. **Actions בפרטי:** Actions → Build APK → Run workflow (ענף `claude/qa-launch-prep-EXqLn`) → ודא שרץ וירוק.
3. **Codemagic בפרטי:** Start new build (ענף ההשקה, workflow `ios-testflight`) — מספיק שה-fetch מצליח; אפשר לבטל את הבילד אחרי דקה. אם fetch נכשל → לחדש את הרשאת ה-GitHub ב-Codemagic ולנסות שוב.
4. ודא ש-`https://rotem-ya.github.io/WhoIsThere/` אכן ירד (זה צפוי ותקין — הכל הועבר).

## שלב 6 — סיבוב מפתחות (עכשיו הזמן, לא חוסם)
1. **מפתח העלאה EA:3B** (היה חשוף כשהריפו היה ציבורי): Play Console → Setup → App integrity → App signing → בקש **upload key reset** → צור keystore חדש עם סיסמה חזקה → העלה את התעודה → אחרי אישור גוגל: עדכן את 4 ה-Secrets בריפו (`UPLOAD_KEYSTORE_BASE64`, `UPLOAD_KEYSTORE_PASSWORD`, `UPLOAD_KEY_ALIAS`, `UPLOAD_KEY_PASSWORD`) והסר את המפתח המוטמע מ-`build-aab.yml`.
2. **PAGES_SYNC_TOKEN:** צור PAT (Fine-grained) עם **Contents: Read & Write על `rotem-ya/apps-share-pages` בלבד** → עדכן את ה-Secret בריפו whoisthere → הרץ Actions → "Sync public pages" → Run workflow לאימות.

## מה צפוי להישבר (מודע — אל תתקן)
- קישורי הזמנת-חבר שנשלחו מבילדים ישנים (v1.1.0 ומטה) → 404. בהודעה יש גם את הקוד להזנה ידנית; מהגרסה הבאה הקישורים החדשים תקינים.
- הורדת ה-QA APK הישירה מ-releases תדרוש התחברות GitHub.

בסיום דווח: אילו שדות עודכנו בכל חנות, שהריפו פרטי, ותוצאות בדיקות שלב 5.
