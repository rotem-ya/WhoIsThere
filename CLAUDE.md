# WhoIsThere — Claude Notes

## ⚠️ חובה לקרוא קובץ זה בתחילת כל סשן לפני כל פעולה

---

## מערכת קוסמטיקה (cosmetics) — נרכשת במטבעות, ללא pay-to-win
ארבעה סוגי קוסמטיקה, כולם באותו דפוס: model+קטלוג בקוד (`lib/models/`), מסך חנות (`lib/screens/store/`) עם providers `selectedXProvider`/`ownedXProvider` (StreamProvider על `users/{uid}`), קנייה = טרנזקציית Firestore (`coins` − מחיר + `totalSpent` increment, `ownedX` arrayUnion), הצמדה = `selectedX` על user doc. באנר בטאב 🎨 (`store_screen.dart` → `_DesignBanner`). מיזוג ב-`auth_service` במעבר אורח→Google (`ownedX`). דרגות לפי מחיר: בסיסי 50–150 / נדיר 300–500 / פרימיום 1000.

| סוג | model | מסך/route | שדה user | היכן נראה | הפצה לשחקנים אחרים |
|-----|-------|-----------|----------|-----------|---------------------|
| מסגרות אווטר | `avatar_frame.dart` | `/store/frames` | `selectedAvatarFrame`/`ownedFrames` | לובי, ניצחון, פרופיל | `PlayerModel.frameId` (RoomService host+join) |
| צבעי שם | `name_style.dart` | `/store/names` | `selectedNameStyle`/`ownedNameStyles` | לובי, פרופיל (לא מסך ניצחון — שם צבעי מקום) | `PlayerModel.nameStyleId` |
| אפקטי ניצחון | `win_effect.dart` | `/store/effects` | `selectedWinEffect`/`ownedWinEffects` | מסך ניצחון (אפקט המנצח, כולם רואים) | `PlayerModel.winEffectId` |
| רקע לוח | `board_skin.dart` | `/store/board` | `selectedBoardSkin`/`ownedBoardSkins` | מסך משחק (רקע) | **פר-צופה** (לא מופץ) — נפרד מ`card_skins` (גב כרטיסיות) |

- רינדור: `PlayerAvatar.frameId` (טבעת SweepGradient), `PlayerNameText` (solid/ShaderMask), `WinEffectOverlay` (מערכת חלקיקים CustomPainter, ללא חבילות), `game_board_screen` רקע מ-`boardSkinFor(...).gradient`.
- הוספת פריט = שורה בקטלוג בלבד. **אל תבלבל** "רקע לוח" (board_skin) עם "עיצובי כרטיסיות" (card_skins, גב המשבצות) — שתי מערכות נפרדות.

---

## משחק עם חברים — בחירת נושאים + טבלת ניקוד פר-משחק
- **מאגר נושאים (חי-צומח-דומם):** 11 קטגוריות ב-`GameCategories.fastHeat`: חיות, פרחים(=plants), דומם(=objects), ציפורים, כלי תחבורה, מקצועות, דגלים, כלי נגינה, פירות וירקות, בגדים, ספורט. כל קטגוריה = `assets/game_places/data/<id>.json` + תמונות ב-`assets/game_places/images/<id>_<name>.jpg` (id+שם קובץ ממורחבים בשם הקטגוריה כדי למנוע התנגשות בתיקייה השטוחה). תוכן מוטמע, `hasHints:false`.
- **מס׳ סבבים:** משחק מהיר = `max(שחקנים, 3)`. חברים = `max(max(שחקנים,3), סה״כ נושאים שנבחרו)` — כל בחירה נוספת של המארח מאריכה את ההיט, עם רצפה של 3/מס׳ שחקנים.
- **בחירת נושאים:**
  - **גלובלי (משחק מהיר):** אקראי אוטומטי, `count = max(targetPlayers, 3)` (4 שחקנים → 4 נושאים). נבנה ב-`createRoom` (`heatRounds` param → `_buildHeat`).
  - **חברים:** **כל משתתף בוחר נושא אחד; המארח יכול לבחור כמה שירצה** (כל בחירה נוספת = סבב נוסף). `topicChoices: Map<playerId, List<categoryId>>`. ב-UI: לא-מארח = בחירה יחידה (לחיצה על נושא אחר מחליפה), מארח = ללא הגבלה. ההיט נבנה ב-`startGameDirectly` מ-`_buildFriendsHeat` (מארח ראשון עם כל בחירותיו, אחר כך כל שאר השחקנים בלוקח-אחד; סלוטים חסרים → אקראי).
  - דיאלוג בלובי כשלא כולם השלימו מכסה: "בחר אקראית והתחל" / "המתן".
- **משחק עם חברים = חינם:** `_createPrivateRoom` יוצר עם `entryFee: 0`, ללא בדיקת מטבעות.
- **ניקוד פר-משחק (לא מצטבר):** במשחק חברים (`room.isFriendsGame == !isPublicRoom`) הניקוד **לא** נוסף ל-`totalPoints`. טבלת הניקוד + הכרזת הזוכה מוצגות במסך הניצחון (קיים).
- **פרסי דירוג חברים:** מקום 1 = 20🪙, מקום 2 = 5🪙 (`EconomyConfig.friendsFirstPlaceReward`/`friendsSecondPlaceReward`). מוענק ב-`RoomService.claimPlacementReward` (אידמפוטנטי דרך `placementPaidPlayerIds`), נקרא ממסך הניצחון לכל שחקן על עצמו.

---

## חי-צומח-דומם — הצבעת "החלף פריט" (כשאף אחד לא יודע)
- אחרי שנחשפו **≥30%** מהמשבצות בסבב היט, מופיע כפתור "🔁 אף אחד לא יודע? החלף פריט" (`game_actions.dart` → `_SkipVoteButton`). לחיצה = הצבעה (toggle); chip מציג `X/סף`.
- **דרוש רוב של שחקנים אנושיים** כדי להחליף: סף = `(מס׳_אנושיים ~/ 2) + 1`. לכן 2 בני אדם → צריך 2 (1-על-1 אמיתי), 3 → 2, 4 → 3.
- **בוטים ניטרליים** — לא מצביעים ולא נספרים. לכן אדם בודד מול בוטים → סף 1 (מחליף לבד); ב-1-על-1 הבוט לא משפיע.
- בעת מעבר רוב: הפריט מוחלף בפריט **אקראי חדש מאותה קטגוריה** (לא בשימוש), החשיפה מתאפסת, **מס׳ הסבבים נשמר** (אותו `heatRoundIndex`).
- **קוד:** `RoomModel.skipVotes` (List<String>) + getters `humanPlayers`/`skipVoteThreshold`/`skipVoteCount`/`skipVotePassed`/`skipVoteEligible(ratio)` + `kSkipVoteMinRevealRatio=0.30`. שירות: `RoomService.voteSkipItem` (טרנזקציה: pre-pick תמונה מחוץ לטרנזקציה, toggle+ספירה בתוכה). `skipVotes` מתאפס ב-`_roundResetUpdates` (כל מעבר סבב/החלפה). gating בצד שרת ולקוח זהה (`room.placedPieces.length / gridSize²`).

---

## כללי פיתוח
- **ענף פיתוח / השקה (מאוחד):** `claude/qa-launch-prep-EXqLn`
  - זהו הענף המאוחד והיחיד לבנייה (iOS + Android). מכיל: 36 מקומות + טקסט עברי מבוקר, Apple Sign-in entitlement, תיקון קריסת "משחק מהיר" (ניטרול Firestore cache), חתימת AAB עם מפתח EA:3B דרך Secrets, וכל הקו הראשי (parallel guessing, quick-match, פרסומות, מפת גילויים).
  - ⚠️ **לבנות אך ורק מהענף הזה.** אין לבנות מ-`stability-compensation-logging` (ענף תקוע/מיושן) או מ-`hebrew-text-review` (מוזג לכאן).
- מאגר: `rotem-ya/whoisthere`

## דף הצטרפות לחדר (Join Page)

### מיקום הקוד
- **קובץ מקור**: `docs/join.html` בריפו WhoIsThere (הריפו הזה)
- **כתובת פרודקשן**: `https://rotem-ya.github.io/apps-share-pages/whoisthere/join/?code=XXXXXX`
- **קובץ יעד**: `whoisthere/join/index.html` בריפו `rotem-ya/apps-share-pages`

### סנכרון אוטומטי
קיים workflow בשם `sync-join-page.yml` שמסנכרן את הקובץ אוטומטית:
- **טריגר**: push ל-`main` שמשנה את `docs/join.html`
- **פעולה**: מעתיק את הקובץ ל-`apps-share-pages/whoisthere/join/index.html` ומבצע push

### דרישה חד-פעמית: הגדרת Secret
כדי שה-workflow יעבוד, נדרש GitHub Personal Access Token עם הרשאות `repo`:
1. צור PAT ב-GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained
2. הרשאות: **Contents: Read & Write** על הריפו `apps-share-pages`
3. הוסף כ-Secret בריפו WhoIsThere: **Settings → Secrets → Actions → New** → שם: `PAGES_SYNC_TOKEN`

### עריכה ידנית (ללא Secret)
אם ה-Secret לא מוגדר או ה-workflow נכשל:
```bash
# קלון apps-share-pages ידנית, עדכן, ודחף
git clone https://github.com/rotem-ya/apps-share-pages.git /tmp/pages
cp docs/join.html /tmp/pages/whoisthere/join/index.html
cd /tmp/pages && git add . && git commit -m "sync join page" && git push
```

### גישת Claude למאגרים
- Claude **יכול** לגשת רק ל-`rotem-ya/whoisthere` דרך MCP
- Claude **אינו יכול** לדחוף ישירות ל-`apps-share-pages` — זה מטופל ע"י ה-workflow
- עריכת הדף: ערוך `docs/join.html`, בצע push ל-main — ה-workflow ידאג לשאר

## חוקי עבודה — חובה לפעול לפיהם
1. **משימה אחת בכל פעם** — לא מתחילים משימה הבאה לפני שהנוכחית הושלמה
2. **אחרי כל משימה: verify + double-check** — בדיקה שהקוד תקין, לא שובר דברים אחרים
3. **אחרי אימות: ממשיכים ללא אישור** — אין צורך לחכות לאישור בין משימה למשימה
4. **push רק אחרי 5 משימות, או בסיום כל המטלות** — לא commit/push אחרי כל משימה בנפרד
5. **לאחר כל שינוי — חפש תופעות לוואי**: האם יש תנאי guard שנשאר ולא עודכן? האם הפיצ'ר עובד בסולו (בוט) ולא רק מולטיפלייר?

## כלכלה — חוקים חשובים
- **100 מטבעות כניסה ראשונה**: חד-פעמי לפי UID (Firestore). מחיקת אפליקציה + אותו חשבון = לא מקבל שוב. אורח עם UID חדש = מקבל. הבדיקה: `totalEarned > 0` ב-wallet document.
- **פרס יומי**: 20 מטבעות בסיס + בונוס לפי streak, מתאפס כל יום UTC.

## מטלות נוכחיות — שלב יציבות
- [x] הסרת פסי טיימר ממסך המשחק
- [x] תיקון כפתור פרס יומי (היה מושבת בטעות)
- [x] בקרת סאונד חיה בהגדרות (slider → צליל מיידי)
- [x] משוב רטט בהגדרות
- [x] deploy Firestore rules + תיקון 100 מטבעות
- [x] חיווי קולי לעוצמת מוזיקה בהגדרות לא עובד (bg player לא מנגן כשלא במשחק)

## מטלות ממתינות — שלב פולישׁ משחק
- [x] מוזיקה נעצרת בהודעת וואטסאפ ולא חוזרת — _musicShouldBePlaying + onPlayerStateChanged listener
- [x] החלפת סאונד הטיק של הספירה לאחור + סנכרון מדויק עם השניות — aperture_open.wav + per-second dedup
- [x] עיצוב מחדש של ספירת לאחור על המשבצת — dark overlay + gold depleting ring + glow
- [x] אלגוריתם חשיפת משבצות — לא סמוכות זו לזו (דמקה), רק אם אין ברירה אחרת

## מטלות שהושלמו — שלב UX משחק
- [x] רמז ראשון 40 מטבעות, רמז שני 80 מטבעות + צפייה חוזרת ברמזים שנקנו
- [x] טיימר גילוי ל-10 שניות (קבוע, לא דינמי)
- [x] כפתור "נחש עכשיו!" תמיד מוצג לכולם
- [x] הסתרת overlay ניחוש מצופים — רק גסחן רואה overlay; שאר רואים ✍ ליד שם
- [x] עיצוב מחדש מסך ניצחון — ללא גלילה, compact image, Flexible scores
- [x] הסרת גלילה מ-LetterBankInput + מסך win
- [x] כפתור חזרה אנדרואיד — Lobby/Vote/Win → חוזר ל/home במקום יציאה מאפליקציה

---

## שלב הבא: מערכת דירוג שחקנים
- [x] מערכת דירוג: 7 דרגות תמטיות לפי totalPoints (עיוור → מתחיל → סקרן → בלש → חוקר → מומחה → אגדה)
- [x] דרגה מוצגת בלובי (ליד שם השחקן), ב-HUD משחק (אימוג'י), ובפרופיל (badge + "לדרגה הבאה: X נק׳")
- [x] totalPoints נשמר ב-PlayerModel ומועתק מ-Firestore בכניסה/יצירת חדר

---

## מטלות ממתינות — שלב אינטראקציה ומשחקיות
- [x] badge גילויים כסופרסקריפט בפינה ימנית עליונה של שם שחקן
- [x] תיקון: תמונות שגויות ב-discoveredImageIds
- [x] כרטיס עצור (stun card) — רכישה בחנות, חסימת שחקן לתור
- [x] מסך "המקומות שגיליתי" — מפת ישראל נאון עם 50 מקומות
- [x] טיפול בסאונד לטיימר — ביטול reveal tick, guess tick מעץ בלבד, daily_coins + player_join + wrong_buzz
- [x] מחיר כניסה לחדר — 20 מטבעות; תצוגה נכונה במסך הבית
- [x] בוטים עם שמות ישראליים אמיתיים (30 שמות)
- [x] לחיצה על שם שחקן במשחק → תפריט כרטיסים (חסימת ניחוש 5s/10s, החשכה)
- [x] כרטיסים חדשים בחנות: חסימת ניחוש 5s (20🪙), 10s (35🪙), החשכה (25🪙)
- [x] overlay החשכה — מסתיר לוח מיריב (blackoutActiveUntilMs); time-block countdown על כפתור ניחוש

---

## מטלות ממתינות — שלב התקדמות ופתיחת תכונות

### מטלות שהושלמו בסשן זה
- [x] סאונד טיק של ספירת לאחור בחשיפת משבצת (reveal-tick player, per-second dedup)
- [x] תזמון חשיפה מאיץ (קשת slow→fast): 3.5s עד 30% גילוי, 2.5s עד 65%, 1.7s באנדגיים (`_revealTimerMs` ב-`room_service.dart`). חלון הניחוש מתכווץ במקביל: 7s→5s→3.5s (`_guessOppTimerMs`).
- [x] ניחוש מותר בכל שלב (לא רק ב-guessOpportunity)
- [x] אין גישה לחנות תוך כדי משחק — הודעת snackbar
- [x] ברירת מחדל מוזיקה 40% (היה 100%)
- [x] כפתורי בית: עיצוב מחדש solid gradient + תיקון overflow טקסט

### מערכת נעילת כרטיסים לפי התקדמות
כרטיסי פעולה נפתחים לרכישה בהתאם למספר המקומות שגולו (`discoveredImageIds.length`).
כל 10 מקומות שגולו → כרטיס חדש נפתח, מהפשוט למורכב:

| גילויים | כרטיס שנפתח | מחיר |
|---------|-------------|-------|
| 0+  | אין כרטיסים | — |
| 10+ | חסימת ניחוש 5s | 20🪙 |
| 20+ | החשכה | 25🪙 |
| 30+ | חסימת ניחוש 10s | 35🪙 |
| 40+ | כרטיס עצור (stun) | 50🪙 |

**איפה לממש:**
- `lib/screens/store/store_screen.dart` → `_CardsTab` → `_PlayingCard`: הוסף `locked: bool` + `requiredDiscoveries: int`
- כרטיס נעול מוצג אפור עם מנעול + "גלה X מקומות לפתיחה"
- קרא `discoveredCount` מ-`ref.watch(currentUserProvider).valueOrNull?.discoveredImageIds.length ?? 0`
- **אל תסתיר** כרטיסים נעולים — הצג אותם כדי לתמרץ את השחקן להתקדם

---

## פלטפורמה אחידה — שני סוגי המשחק (ומשחקים עתידיים)

**עיקרון:** כל סוגי המשחק רוכבים על אותה תשתית. פיצ'ר רוחבי (תוכן ענן, צ'אט, אווטרים…) מתווסף ב**נקודת חנק משותפת אחת** ולכן עובד אוטומטית בכל הסוגים — אין להעתיק לוגיקה לכל מסך בנפרד.

### תוכן מהענן + אדמין (פעיל/לא-פעיל + מקומות חדשים) — אחיד לכל הקטגוריות
- נקודת חנק יחידה: `RoomService._loadLocalImages({categoryId})` → ממזג מוטמע (`assets/.../<id>.json`) + תמונות remote מהמניפסט **לפי קטגוריה** (`ContentManifestService.availableRemoteImages(categoryId)`), עם רשת ביטחון לברירות מחדל מוטמעות.
- סנכרון בהפעלה (`loadCached` + `sync`) ב-`main.dart` — תשתית משותפת, רצה פעם אחת לכל המצבים.
- **המשחק הרגיל** (זיהוי מקומות) משתמש בקטגוריה `israel_places`. **חי צומח דומם** (מקצה) משתמש ב-`animals`/`plants`/`objects` דרך `_buildHeat` → אותו `_loadLocalImages(categoryId)`. לכן הוספת/השבתת תמונה מהאדמין עובדת **גם** בחי צומח דומם, ללא קוד נוסף.
- **חוזה אדמין (קריטי לאחידות):** כל מקום remote במניפסט חייב לשאת שדה `category` עם אחד מה-ids: `israel_places` / `animals` / `plants` / `objects` (וגם `world_sites` / `israel_figures` / `world_figures` לעתיד). ברירת מחדל בהיעדר השדה = `israel_places` (כלומר ייכנס רק למשחק הרגיל). ids חייבים להיות זהים בדיוק ל-`GameCategories` ב-`lib/core/constants/game_categories.dart`.

### צ'אט (טקסט חופשי + אימוג'ים) — אחיד לכל המצבים
- `RoomService.sendChatMessage` / `chatMessagesStream` על תת-אוסף `rooms/{id}/messages` (rules מכוסה ב-`{document=**}`).
- ה-UI (כפתור 💬, גיליון הצ'אט, טוסטים, בוטים) ב-`game_board_screen.dart` מגודר רק על `phase == GamePhase.playing` — **לא** על `isHeat`. לכן הצ'אט קיים גם במשחק הרגיל וגם בחי צומח דומם.

### כשמוסיפים סוג משחק חדש
- הוסף קטגוריה ב-`GameCategories` (id חדש + JSON). השתמש ב-`_loadLocalImages(categoryId)` לבחירת תמונות → תוכן הענן והאדמין מגיעים בחינם.
- אל תגדר פיצ'רים רוחביים (צ'אט/אווטרים/תוכן) ב-`isHeat`/id ספציפי — גדר רק על `phase`/יכולת, כדי שיישארו אחידים.

---

## משחק האותיות (משחק חדש) — מצב + מטלות דחויות
משחק וורדל-עם-תמונות, 1 נגד 1 תורות. התשובה = שם עברי של תמונה אקראית מכל הקטגוריות (בלי כותרת נושא). אות במיקום מדויק (ירוק) → 4 משבצות; אות שקיימת במקום אחר (צהוב) → 2; חוטא → 0. **לוח נפרד לכל שחקן**, לוח זכוכית-מט 8×8 (משבצות שהיריב חשף = זכוכית אדומה מט). ניצחון אוטומטי למשלים ראשון.
- **קוד:** `mode:'letters'` + `secretWord`/`lettersRevealedTiles`/`lettersGuessed`/`lettersSolvedSlots` ב-`RoomModel`; לוגיקה טהורה ב-`lib/core/utils/letters_matcher.dart` (+ טסטים); שירות `createLettersRoom`/`guessLetterInLettersGame` ב-`room_service`; מסך `lib/screens/game/letters_game_screen.dart` (route `/letters/:roomId`); כניסה מהבית = כפתור "🔤 משחק האותיות".
- **מולטיפלייר (מומש):** חברים = חדר פרטי בקוד (`createLettersRoom(solo:false, isPublicRoom:false)`, המסך מציג קוד; המארח מתחיל כשנכנס שחקן 2 דרך `startLettersGame`). אקראי = `findLettersMatch` (סינון `mode=='letters'` בקוד על אינדקס waiting+public קיים) או חדר ציבורי ממתין עם נפילה לבוט אחרי 8ש׳. כל סוגי המשחק (מקומות/חי-צומח-דומם/אותיות) נכנסים דרך מסך הבית עם בורר "נגד מי?" (אקראי/חברים).
- **מטלות דחויות (לבקשת רוטם — להזכיר):**
  - [ ] פוליש: אנימציות חשיפה/מחוון תור, אולי טיימר קצר לתור, בדיקה חיה על מכשיר (ביצועי ה-blur של 64 משבצות), טיפול במצב-קצה של מירוץ הצטרפות (יותר מ-2 שחקנים בחדר אותיות).

---

## הזמנה ל-Play Store — QA Launch Prep

### סטטוס: ✅ נפתר (מסלול A — נמצא מפתח ההעלאה הנכון EA:3B)

#### מה קרה
- **המפתח הנכון נמצא:** `upload-keystore.jks` (alias `upload`, סיסמה `123456`) — SHA1 = `EA:3B:59:B9:2D:4D:F2:58:77:4C:33:55:76:F3:42:46:CC:11:D0:75`, בדיוק מה ש-Play מצפה לו.
- ה-workflow `build-aab.yml` עודכן לחתום במפתח הזה; בנייה (run #4) עברה בהצלחה והלוג מאשר `SHA1: EA:3B`.
- **לא נדרש** איפוס מפתח ב-Play Console. ה-AAB מתקבל כמו שהוא.
- המפתח+סיסמאות הועברו מהקוד ל-**GitHub Secrets** (commit `1fa478f`): `UPLOAD_KEYSTORE_BASE64`, `UPLOAD_KEYSTORE_PASSWORD`, `UPLOAD_KEY_ALIAS`, `UPLOAD_KEY_PASSWORD`.

#### ⏳ מטלות אבטחה ממתינות — לטפל בזמן אחר
- [ ] **להוסיף את ה-4 Secrets בפועל** ב-GitHub (Settings → Secrets → Actions). עד שזה לא נעשה — בנייה חדשה תיכשל (אין מפתח). ה-AAB שכבר נבנה תקין להעלאה.
- [ ] `build-apk.yml` עדיין מכיל את המפתח הישן `25:C3` + סיסמה בקוד — להעביר גם אותו ל-Secrets.
- [ ] לנקות קבצים שלא נחוצים יותר: `android/upload_certificate.pem` + תיעוד מסלול B.
- [ ] שקול keystore עם סיסמה חזקה (כרגע `123456`).


---

## העלאה ל-App Store (iOS / TestFlight)

בנייה והעלאה ל-TestFlight רצות **כולן ב-CI** (GitHub Actions, runner macOS) — אין צורך לפתוח Xcode במחשב. ה-workflow הוא `.github/workflows/build-ios.yml`, שמריץ את fastlane lane `beta` (קבצים: `ios/fastlane/Fastfile`, `ios/fastlane/Appfile`, `ios/ExportOptions.plist`). מספר ה-build נלקח אוטומטית ממספר ריצת ה-workflow, והאימות מול App Store Connect הוא דרך App Store Connect API Key (ולא סיסמת Apple ID).

### 7 ה-Secrets הנדרשים
יש להוסיף אותם ב-**Settings → Secrets and variables → Actions → New repository secret**:
- `APPSTORE_API_KEY_ID` — ה-Key ID של מפתח App Store Connect API
- `APPSTORE_API_ISSUER_ID` — ה-Issuer ID של מפתח App Store Connect API
- `APPSTORE_API_KEY_P8` — קובץ ה-.p8 של המפתח, מקודד base64
- `IOS_DIST_CERT_P12` — תעודת ההפצה (Distribution) כקובץ .p12, מקודד base64
- `IOS_DIST_CERT_PASSWORD` — הסיסמה של קובץ ה-.p12
- `IOS_PROVISION_PROFILE` — פרופיל ה-Provisioning (App Store) כקובץ .mobileprovision, מקודד base64
- `APPLE_TEAM_ID` — מזהה ה-Team של חשבון Apple Developer

### צעדים חד-פעמיים (ידני, ע"י אדם — לא ב-CI)
1. הרשמה ל-**Apple Developer Program** (חשבון בתשלום).
2. יצירת רשומת אפליקציה ב-**App Store Connect** עם bundle id `com.rotem.whoisthere`.
3. יצירת **App Store Connect API Key** (Users and Access → Integrations / Keys) — שמירת קובץ ה-.p8, ה-Key ID וה-Issuer ID.
4. יצירת/ייצוא **תעודת Distribution** (קובץ .p12 עם סיסמה) ו-**פרופיל Provisioning** מסוג App Store עבור `com.rotem.whoisthere`.
5. קידוד הקבצים ל-base64 והדבקתם ב-Secrets המתאימים (לדוגמה: `base64 -i AuthKey.p8 | pbcopy`).

### איך מריצים
Actions tab → בוחרים את ה-workflow **Build iOS (TestFlight)** → **Run workflow** (טריגר `workflow_dispatch` בלבד). ה-workflow מפענח את ה-secrets לקבצים, מייבא תעודה + פרופיל ל-keychain זמני, ממלא את `ExportOptions.plist` (Team ID + שם הפרופיל), בונה IPA חתום ומעלה אותו ל-TestFlight דרך pilot. מספר ה-build נקבע אוטומטית מ-`GITHUB_RUN_NUMBER`.
