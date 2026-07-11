# WhoIsThere — Claude Notes

## ⚠️ חובה לקרוא קובץ זה בתחילת כל סשן לפני כל פעולה

---

## 🚀 סטטוס חנויות
### v1.1.0 — הוגש לשתי החנויות (2026-07-05), אין בלוקרים
- **App Store:** 1.1.0 (**build 1061**) — **Waiting for Review**. Apple ID: `6776076758` · https://apps.apple.com/app/id6776076758 (מקובע ב-`AppConstants.appStoreUrl`).
- **Google Play:** 1.1.0 (**versionCode 25**, ריצת build-aab #25) — Closed testing (Alpha), **בבדיקה**. חתימת EA:3B תקינה, "מה חדש" הוזן, מדינות ללא EU.
- נבנה מ-`claude/qa-launch-prep-EXqLn` קומיט `a42cf83` (iOS דרך Codemagic תג `ios-v3`; AAB דרך marker). תוכן הגרסה: ראה "עדכוני סשן 2026-07-04" + תיקון בוטים (לא מנחשים נכון לפני 50% חשיפה).

### v1.0 — הושקה (2026-07-03)
- **Google Play:** ✅ אושר — Closed testing (Alpha), versionCode 22, חתום EA:3B, ללא EU-27, 22 בודקים.
- **App Store:** ✅ אושר (2026-07-03) — build 1059 (r15).
- **ענף השקה:** `claude/qa-launch-prep-EXqLn`.

### תיקוני דחיית אפל (מומשו, בשתי החנויות)
1. **2.1(b) IAP:** הוסר ממשק רכישת-כסף לא-פעיל מהחנות (`store_screen.dart`, טאב "🎁 מטבעות"). מטבעות = מטבע-משחק בלבד. **אין IAP** — קנייה אמיתית דחויה ל-v1.1.
2. **5.1.1(v) מחיקת חשבון:** כפתור "מחק חשבון" בפרופיל → `AuthService.deleteAccount()` (מוחק Firestore + Auth, re-auth ל-Google/Apple). כלל Firestore: `allow delete: if request.auth.uid == userId` (נפרס ל-main).
3. **2.1 ATT:** `app_tracking_transparency` — בקשה אחרי frame ראשון, **לפני** איתחול AdMob (`main.dart._initTrackingThenAds`).
4. **תיקון Apple sign-in:** התאוששות מבאג Pigeon (`_isPigeonCastError` → `_recoverFromSignInError`) — כמו במסלול Google.

### ⚠️ חתימת Play — קריטי (EA:3B)
- מפתח ההעלאה ה**נכון** ל-Play הוא **SHA1 EA:3B:59:B9:2D:4D:F2:58:77:4C:33:55:76:F3:42:46:CC:11:D0:75** (alias `upload`, סיסמאות `123456`). התעודה נושאת CN="ask the kids" (שם קוסמטי — המפתח הוא הנכון).
- ה-25:C3 הוא מפתח ה-**QA APK** בלבד — **לא** מתקבל ב-Play.
- `build-aab.yml` חותם ב-EA:3B (כרגע **מוטמע** ב-workflow כי הדבקת secret בנייד נכשלה) + שלב אימות שנכשל אם ה-AAB לא EA:3B.
- **⚠️ TODO אבטחה אחרי ההשקה:** המפתח EA:3B מוטמע בריפו **ציבורי**. לאחר אישור: לאפס upload key ב-Play למפתח טרי, לאחסן כ-secret (ממחשב), ולהסיר את המוטמע.
- **מעבר לריפו פרטי — התשתית מוכנה (2026-07-05):** כל הדפים הציבוריים (privacy/support/friend/join/download) + ה-seed לאדמין הועברו ל-`apps-share-pages` (נשאר ציבורי) והקוד עודכן. לפני ההפיכה: לעדכן את כתובות ה-privacy/support בשתי החנויות. **הצ'קליסט המלא והמחייב: `docs/GO_PRIVATE_CHECKLIST.md`.**

### v1.1 — מומש (ענף `claude/google-connect-review-submit-mp11cq`, גרסה 1.1.0)
- [x] **משוב (feedback)** — כפתור "שלח משוב" בפרופיל → `ReportService.submitFeedback` → `feedback/{id}`.
- [x] **שליחת לוג אוטומטית** — `ReportService.reportCrash` (מ-`FlutterError.onError`/`platformDispatcher.onError` ב-main) → `crash_reports/{id}` עם `QaLogger.recentLog()`, throttled/deduped/fail-soft.
- [x] **שיתוף האפליקציה** — כפתור "שתף את האפליקציה" בפרופיל → `Share.share` עם `AppConstants.shareMessage`. קישור Play נגזר מה-package; קישור App Store מ-`app_config/app.iosUrl` (אדמין).
- [x] **רשימת האפליקציות שלנו** — מסך `OurAppsScreen`, **נשלט מהאדמין** דרך `app_config/app.ourApps` (list של name/subtitle/emoji/androidUrl/iosUrl). השורה בפרופיל מופיעה רק כשיש ≥1 אפליקציה — אין hardcode, הרשימה גדלה בלי בילד.
- [x] **הגירת אורח→חשבון** — אורח שמתחבר לגוגל/אפל קיים: נתוני האורח נלכדים, האורח **נמחק** (עוד כאורח, כי rules מתירים מחיקת-עצמי), ואז הנתונים נכתבים על החשבון (`_captureGuestData`+`_writeMergedData`+`_GuestSnapshot`). אורח→חשבון חדש = שדרוג-במקום.
- **בנייה:** גרסה `1.1.0` (build_info + build-aab default + codemagic). Build APK CI ירוק (compile מאומת). ⚠️ **בניות החנות דורשות הפעלה ידנית** (ל-cowork/agent אין הרשאת Actions/tag): AAB דרך Actions→Build AAB→Run workflow (build_name=1.1.0) או תג `aab-v2`; iOS דרך תג `ios-v3` או Start build ב-Codemagic. ⚠️ v1.0 עדיין ב-review בשתי החנויות — cowork יחליט על תזמון הגשת v1.1.
- (עתידי — ענף `claude/push-invites`: פוש להזמנות — דורש Blaze+APNs.)

### עדכוני סשן 2026-07-04 (על ענף ההשקה, אחרי מיזוג v1.1)
- **ענף ההשקה `claude/qa-launch-prep-EXqLn` הוא המקור היחיד** — מוזג אליו כל v1.1 (mp11cq) + כל תיקוני הסשן. `claude/rematch-bug-investigation-az4n6h` מצביע על אותו קומיט. בוצעה ביקורת ענפים מלאה: כל קוד יוני ממוזג (הזמנות+צ'אט חברים, שורת עדכון בפרופיל, מקלדת סופיות, 73 תמונות מעודכנות, שיתוף, OurApps); ענפי מאי = היסטוריה ישנה; `claude/push-invites` = עתידי מכוון.
- **באג "משחק חוזר" תוקן** (3 כשלים): הצטרפות כושלת ניווטה ללובי זר; "שחק שוב" באותיות יצר חדר סולו נפרד (עכשיו rematchRoomId כמו במשחק הראשי + איפוס State ב-didUpdateWidget כי GoRouter ממחזר את המסך בין /letters/A ל-B); מרוץ שני לוחצים מפצל קבוצה (עכשיו טרנזקציה `_claimRematchSlot`).
- **סנכרון סבבים בחי-צומח-דומם:** ניחוש נכון סוגר את ההקלדה אצל כולם (cycle advance) + guard `stale_image` ב-submitAnswer (ניחוש נשפט רק מול התמונה שעבורה הוקלד). **מסך ביניים** 4ש׳ בין תמונות (`roundInterludeUntilMs`/`lastRoundImageId`/`lastRoundWinnerName` על החדר, `_RoundInterludeOverlay`) — החשיפה הראשונה של הסבב הבא נדחית מעבר להשהיה.
- **בחירת נושאים:** מארח שכיסה את כל הסבבים מבטל את חובת הבחירה לשאר (`_picksCoverHeat`, מכסה 0); מילוי סלוטים חסרים = **מחזורי מהנושאים שנבחרו** (אקראי רק כשאין בחירות) → קטגוריה אחת = כל המקצה בקטגוריה. כפתור "ביטול" בחלון ההקלדה (`onGuessCancel`).
- **חברים:** קישור ההזמנה עבר ל-Pages של הריפו (`rotem-ya.github.io/WhoIsThere/friend.html`) כי הסנכרון ל-apps-share-pages שבור (ראה למטה); retry לאוטו-הוספה כשהמשתמש נטען אחרי הקישור; UX ברור בטאב הוספה (העתק/הדבק/הסברים); **באנר גלובלי `FriendRequestBanner`** (מעל הראוטר ב-main.dart) לבקשות ממתינות מכל מסך.

---

## מערכת קוסמטיקה (cosmetics) — נרכשת במטבעות, ללא pay-to-win
> **קטלוג חי (v1.1.1+):** האדמין שולט בכל 4 סוגי הקוסמטיקה דרך `cosmetics_catalog/catalog_v1` (קריאה ציבורית, כתיבה isAdmin) — `CosmeticsCatalogService` ממזג אל ה-hooks בקבצי המודל (`liveX`/`allX`), דריסה לפי id / הוספה / `active:false` להסתרה; רקע-לוח תומך `imageUrl` (תמונה מ-Gemini ב-Storage). מסך האדמין: "🎨 מוצרי חנות (חי)" (v117+; מ-v122 כולל טאב חמישי **🃏 גב כרטיסיות** — אוסף `card_skins` הנפרד, עם תצוגה מקדימה ו-Gemini; מסך "סקיני קלפים" הישן הוסר מהתפריט). המסכים מתרעננים דרך `cosmeticsRevisionProvider`.
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
  - **חברים:** **כל משתתף בוחר נושא אחד; המארח יכול לבחור כמה שירצה** (כל בחירה נוספת = סבב נוסף). `topicChoices: Map<playerId, List<categoryId>>`. ב-UI (`lobby_screen.dart` → `_onTopicTap`): **נושא שנבחר ע"י כל משתתף מוצג כנבחר אצל כולם עם שם הבוחר** (chip מודגש). לא-מארח: בוחר נושא אחד **ולא יכול לבטל/להחליף בעצמו** — לחיצה אחרי שבחר מציגה snackbar "רק המארח יכול לבטל". מארח: בוחר ללא הגבלה, ו**רק הוא יכול לבטל בחירה של משתתף — עם דיאלוג אישור** (`_confirmCancelChoice`); ביטול בחירה עצמית של המארח הוא חופשי (ללא דיאלוג). ההיט נבנה ב-`startGameDirectly` מ-`_buildFriendsHeat` (מארח ראשון עם כל בחירותיו, אחר כך כל שאר השחקנים בלוקח-אחד; סלוטים חסרים → **מילוי מחזורי מהנושאים שנבחרו**, אקראי רק כשאין בחירות כלל — כך קטגוריה אחת = כל המקצה בה).
  - **פטור מבחירה:** כשהבחירות כבר מכסות את כל הסבבים (`_picksCoverHeat` — ספירה מארח-כל-בחירותיו/אחרים-אחת מול רצפת `max(שחקנים,3)`), המכסה של כולם יורדת ל-0 — אין דיאלוג חוסם והצ'יפים ירוקים.
  - דיאלוג בלובי כשלא כולם השלימו מכסה: "השלם והתחל" / "המתן".
- **משחק עם חברים = חינם:** `_createPrivateRoom` יוצר עם `entryFee: 0`, ללא בדיקת מטבעות.
- **ניקוד פר-משחק (לא מצטבר):** במשחק חברים (`room.isFriendsGame == !isPublicRoom`) הניקוד **לא** נוסף ל-`totalPoints`. טבלת הניקוד + הכרזת הזוכה מוצגות במסך הניצחון (קיים).
- **פרסי דירוג חברים:** מקום 1 = 20🪙, מקום 2 = 5🪙 (`EconomyConfig.friendsFirstPlaceReward`/`friendsSecondPlaceReward`). מוענק ב-`RoomService.claimPlacementReward` (אידמפוטנטי דרך `placementPaidPlayerIds`), נקרא ממסך הניצחון לכל שחקן על עצמו.

## חוויית חברים — קבוצות, הזמנות פוש, ניקוד מקצה (מומש 2026-07-11)
- **טבלת ניקוד בסוף מקצה:** `_RoundInterludeOverlay` (game_board_screen) הורחב — התמונה שנפתרה+התשובה, דירוג חי של כולם (המנצח מודגש עם +נקודות), ופס תמונות של כל הסבבים שהושלמו (`_interludeGallery`). משך הביניים הוארך ל-6.5ש' (`heatInterludeMs`).
- **טוגל תחבולות (משחק חברים קלאסי):** `RoomModel.tricksEnabled` (ברירת מחדל true) — טוגל מארח בלובי חברים (`_TricksToggleRow`; מוצג רק כשלא-heat כי בהיט הכרטיסים ממילא כבויים). נאכף בשלוש טרנזקציות הכרטיסים ב-room_service, מאפס מוני כרטיסים ב-HUD, וגיליון הפעולות מציג "המארח כיבה את התחבולות".
- **הזמנות משחק בפוש+באנר:** ה-cloud function `onGameInvite` (functions/index.js) כבר שולח פוש על כתיבת `gameInvites/{toUid}_{fromUid}`. חדש: `GameInviteBanner` גלובלי (main.dart, לצד FriendRequestBanner) עם "הצטרף" שמצרף ופותח לובי בלחיצה מכל מסך; לחיצה על הפוש עצמו עושה join ישיר לחדר (`_joinFromPush` ב-main, עם המתנה ל-auth בקולד-סטארט ונפילה ל-/friends). ⚠️ הפוש דורש שה-functions פרוסות (Blaze): `firebase deploy --only functions`.
- **קבוצות חברים קבועות:** `groups/{id}` (GroupModel: members, memberNames, points מצטבר) + `messages` (צ'אט קבוע, אותה סכימה כמו צ'אט חדר → `ChatSheet` המשותף) + `games/{roomId}` (אידמפוטנטיות ניקוד). `GroupsService` (create/leave/delete, `inviteGroupToRoom` — הזמנת פוש לכל החברים בלחיצה, `recordMyGroupResult` — כל שחקן רושם את עצמו, כמו friendsGamePoints). `RoomModel.groupId` נקבע ביצירה ומשומר ב-rematch ("שחק שוב עם החבורה"). UI: טאב "קבוצות" במסך החברים (`widgets/groups_tab.dart`) — יצירה (שם+בחירת חברים), כרטיס קבוצה עם לוח ניקוד, "שחק עכשיו" (בורר משחק → **בורר מוזמנים**: כולם מסומנים כברירת מחדל / בחירה חלקית → חדר+הזמנות+לובי), צ'אט. כללי Firestore: `groups/{groupId}/{document=**}` ל-signedIn (נפרס גם מענף הסשן — deploy-firestore-rules.yml).
- **הצטרפות לקבוצה דורשת אישור (מומש 2026-07-11, כמו וואטסאפ):** יצירת קבוצה מוסיפה רק את היוצר כחבר; כל מי שנבחר מקבל הזמנה ב-`groupInvites/{toUid}_{groupId}` (`GroupsService.inviteMemberToGroup`/`createGroup`) ולא נכנס אוטומטית. חבר נהיה חבר רק אחרי `acceptGroupInvite` (מוסיף ל-`memberUids`, אז `myGroupsProvider` חושף לו את הקבוצה); `declineGroupInvite` רק מוחק את ההזמנה, בלי חברות. פוש: `onGroupInvite` (functions/index.js, אותו דפוס onWrite כמו onGameInvite). UI: `GroupInviteBanner` גלובלי (main.dart, מתחת ל-FriendRequestBanner/GameInviteBanner עם היסט מצטבר) עם הצטרף/דחה ישירות מהבאנר, וגם `_GroupInviteCard` בראש טאב "קבוצות" (זמין גם אם הבאנר נסגר). כלל Firestore: `groupInvites/{inviteId}` ל-signedIn.

## מערכת חברים (Friends)
- **מסך:** `lib/screens/friends/friends_screen.dart` (route `/friends`, כפתור 👥 במסך הבית עם נקודת התראה לבקשות ממתינות). 3 טאבים: טבלת ניקוד / חברים+בקשות / הוסף חבר.
- **שירות:** `FriendsService` (`lib/services/friends_service.dart`). **קוד חבר אישי** (`users/{uid}.friendCode`, נוצר חד-פעמית, ייחודי) + שיתוף בוואטסאפ. הוספה: `sendRequestByCode` (אם הצד השני כבר שלח לי — מתחברים ישירות).
- **אוטומציה בשיתוף (deep link):** קישור הזמנה `AppConstants.friendInviteUrl(code)` → דף נחיתה `docs/friend.html` המוגש מ-**Pages של הריפו הזה**: `https://rotem-ya.github.io/WhoIsThere/friend.html` (⚠️ ה-workflow `sync-join-page.yml` **שבור** — `PAGES_SYNC_TOKEN` בלי הרשאת כתיבה (403); לתקן: PAT חדש עם Contents:RW על apps-share-pages. ב-2026-07-05 הדפים friend/join/privacy הועלו **ידנית** ל-apps-share-pages, כך שגם הקישורים הישנים בפורמט `apps-share-pages/whoisthere/friend/` עובדים — אבל עדכוני דפים עתידיים לא יסתנכרנו עד תיקון ה-PAT). הדף פותח אוטומטית `whoisthere://friend?code=` (scheme רשום ב-AndroidManifest host=`friend` + iOS; ה-handler וה-manifest מזהים את **שני** ה-hosts). `main.dart._handleDeepLink` מזהה friend → `pendingFriendCodeProvider`; `FriendsScreen` שולח את הבקשה **אוטומטית** בכניסה (`_maybeAutoAddFromInvite` + retry דרך `ref.listen(currentUserProvider)` ל-cold-start). cold-start: `HomeScreen` מנווט ל-`/friends`. **באנר גלובלי** `FriendRequestBanner` (main.dart builder) מציג בקשות ממתינות מכל מסך.
- **Firestore:** `friendRequests/{toUid}_{fromUid}` (בקשות), `users/{uid}/friends/{friendUid}` (חברות, נכתבת לשני הצדדים), `users/{uid}/friendGames/{roomId}` (היסטוריית משחק פר-שחקן). כללים ב-`firestore.rules` (read/write ל-signedIn; כתיבות חוצות-משתמש לחברויות).
- **ניקוד:** מצטבר ב-`users/{uid}.friendsGamePoints` (נפרד מ-`totalPoints`). **כל קליינט רושם רק את עצמו** ב-`recordMyResult` (אידמפוטנטי פר שחקן/חדר; Firestore מתיר כתיבה רק למסמך המשתמש של עצמך). מופעל מ-`_triggerMatchReward` (game_board_screen) ב-`room.isFriendsGame`. טבלת הניקוד = אני + חברים ממוינים לפי `friendsGamePoints` (`leaderboard`), + רשימת משחקים אחרונים.
- ⚠️ **חוקי Firestore חדשים** — נדרס deploy (workflow `deploy-firestore-rules.yml` רץ על push ל-main).

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
  - זהו הענף המאוחד והיחיד לבנייה (iOS + Android). נכון ל-2026-07-04 מכיל את **הכל**: הקו הראשי, כל v1.1 (mp11cq), תיקוני "משחק חוזר", סנכרון סבבים + מסך ביניים, ותיקוני החברים. ענף `claude/rematch-bug-investigation-az4n6h` זהה לו.
  - ⚠️ **לבנות אך ורק מהענף הזה.** אין לבנות מ-`stability-compensation-logging` (ענף תקוע/מיושן) או מ-`hebrew-text-review` (מוזג לכאן). ענפי מאי (`lc-*`, `loop-*` וכו') = היסטוריה ישנה שנכתבה מחדש — לא למזג מהם.
  - `main` משמש רק לתשתית שנפרסת ממנו: Firestore rules (`deploy-firestore-rules.yml`), GitHub Pages (docs/), וסנכרון דפי share. קוד האפליקציה חי בענף ההשקה.
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

## טיפול במשוב וקריסות ממשתמשים — השגרה
- משוב → `feedback/{id}`; קריסות אוטומטיות (עם לוג מהמכשיר) → `crash_reports/{id}`. צפייה/סימון-טופל: מסך "📬 משוב וקריסות" באדמין (v114+).
- **העברה לטיפול קלוד:** רותם מוריד באדמין "📦 הורד ZIP" (v115+; מציע מחיקה מהענן אחרי) ומעלה את `whoisthere_inbox_*.zip` לצ'אט. קלוד עובר על הפריטים הלא-מטופלים (`handled != true`): מאבחן קריסות מהלוג, מתקן באגים, ממפה משוב לצ'קליסט, ומחזיר סיכום עם מה לסמן "טופל".

## סנכרון מול אפליקציית האדמין — חובה
- ריפו האדמין: `rotem-ya/Guess_The_Place_Admin` (אפליקציית ווב סטטית, GitHub Pages משלה; קוראת/כותבת Firestore ישירות).
- **כל שינוי בצד המשחק שמצריך עבודה באדמין** (שדה חדש ב-Firestore, אוסף חדש, כלל rules, חוזה תוכן, כתובת שהשתנתה) — **חייב להירשם מיד** כרשומה חדשה ב-`handoff/FROM_GAME_PENDING.md` בריפו האדמין (רישום מצטבר; רותם מרוקן אותו מדי פעם ע"י בקשת מימוש). כדי לכתוב לריפו האדמין מסשן: `add_repo rotem-ya/Guess_The_Place_Admin` ואז clone/commit/push רגיל.
- הכיוון ההפוך (אדמין→משחק): `handoff/FOR_GAME_CLAUDE.md` באותו ריפו — לבדוק אותו בתחילת סשן משחק.
- קטלוג המשחק מוגש לאדמין מ-Hosting: `https://whoisthere-380fa.web.app/assets/game_places/...` (נארז ב-deploy-hosting מ-assets, לא ב-git) — אין להחזיר תלות ב-raw.githubusercontent.

## חוקי עבודה — חובה לפעול לפיהם
1. **משימה אחת בכל פעם** — לא מתחילים משימה הבאה לפני שהנוכחית הושלמה
2. **אחרי כל משימה: verify + double-check** — בדיקה שהקוד תקין, לא שובר דברים אחרים
3. **אחרי אימות: ממשיכים ללא אישור** — אין צורך לחכות לאישור בין משימה למשימה
4. **push רק אחרי 5 משימות, או בסיום כל המטלות** — לא commit/push אחרי כל משימה בנפרד
5. **לאחר כל שינוי — חפש תופעות לוואי**: האם יש תנאי guard שנשאר ולא עודכן? האם הפיצ'ר עובד בסולו (בוט) ולא רק מולטיפלייר?
6. **שאלות בחירה = בורר צ'ק-בוקס אינטראקטיבי (AskUserQuestion), לא רשימת מרקדאון**. כשמציעים לרותם לבחור מרשימה — כל אפשרות = פריט לבחירה (multi-select כשאפשר לבחור כמה). מגבלה: עד 4 אפשרויות לשאלה, עד 4 שאלות = 16 פריטים; יותר → לפצל לקבוצות בכמה סבבים. (שיטת עבודה מלאה: `docs/WORKFLOW.md` בריפו האדמין.)
7. **טקסט גלוי למשתמשים לעולם לא ישמע כמו טקסט שכתבה בינה מלאכותית** — כולל איסור מוחלט על מקף ארוך (—). כללים מלאים: `docs/NO_AI_TELLS_STYLE.md`. חל על כל טקסט באפליקציה, תיאורי חנות, push, עמודי נחיתה — לא חל על קוד/קומיטים/תיעוד פנימי.

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

## מטלות ממתינות — חנות וקוסמטיקה (רותם, 2026-07-11)
- [x] **אפקטי ניצחון — מומש (2026-07-11):** הקטגוריה הוסרה מהחנות (route+כרטיס), מסך הניצחון מנגן "מופע זיקוקים" (grand_finale) לכל מנצח, ורוכשי-עבר מקבלים **החזר מטבעות מלא אוטומטי** בפתיחת האפליקציה (`AuthService.refundRetiredWinEffects`, אידמפוטנטי דרך `winEffectsRefundedAt`). winEffectId נשאר במודלים לתאימות.
- [סגור] פירוט מקורי:  מסירים את קטגוריית אפקטי הניצחון מהחנות (כמו שהוסרו מסגרות/צבעי-שם ב-v1.1.1), ובוחרים אפקט ניצחון איכותי אחד שיפעל לכולם כברירת מחדל (מועמד טבעי: "מופע זיקוקים" grand_finale). לוודא: PlayerModel.winEffectId, מסך ניצחון, מיזוג אורח→חשבון, ומה קורה למי שכבר קנה אפקט (פיצוי מטבעות?).
- [x] **חוויית חברים — מומש (2026-07-11):** ראה סעיף "חוויית חברים" למטה. נותר: פריסת functions (Blaze) אם עוד לא נפרסו, ובדיקה חיה ממכשירים.
- [~] **הנגשת הזמנות — רובה מומש:** פוש+באנר+קבוצות (ראה "חוויית חברים"); קישור `join?code=` (עמוק/https) עכשיו **מצרף ישירות לחדר** (warm start; נפילה למסך הקוד). נותר: כניסה מהיסטוריית משחקים + בדיקת מסע מלאה ממכשיר.
- [סגור] פירוט מקורי:  היום זה מסורבל מדי (פתח חדר → קוד → שיתוף ידני → "יש לי קוד" → הקלדה). כיווני פתרון לתכנן ולתעדף: הזמנת חבר-מהרשימה בלחיצה אחת מהלובי (לחבר מחובר — פוש/באנר "X מזמין אותך" עם כפתור הצטרף, ראה ענף claude/push-invites); קישור הזמנה עמוק שפותח ישר את החדר (deep link whoisthere://join?code= כמו קישור החברים); כפתור "שחק שוב עם אותה חבורה"; כניסה לחדר מהיסטוריית משחקים אחרונים. לבדוק את כל המסע ממכשיר אמיתי ולמדוד כמה צעדים נחסכו.
- [x] **בחירת מארח: משחק חברים עם/בלי תחבולות.** מומש 2026-07-11 (ראה "חוויית חברים").
- [סגור] פירוט מקורי:  טוגל בלובי חברים (ברירת מחדל: עם) שמכבה את כרטיסי הפעולה במשחק — חסימות ניחוש, החשכה, עצור. מימוש: דגל על החדר (למשל `tricksEnabled`), גיטוי בתפריט לחיצה-על-שחקן וב-overlays; לא נוגע במשחק אקראי/ציבורי. לוודא סנכרון לכל המשתתפים ושהבוטים מכבדים את הדגל.
- [~] **אווטרים 3D — התשתית מומשה (2026-07-11), נותרה הפקת תמונות:** אדמין v161 — טאב "🧑‍🚀 אווטרים" במסך מוצרי החנות (54 המוטמעים, Gemini פר-פריט/batch עם פרומפט פורטרט לפי מדרגת מחיר, גלריה, פרסום). משחק — `cosmetics_catalog.avatars` נטמע ב-`liveAvatarChoices`; `AvatarChoice.imageUrl/active`; `PlayerAvatar` מציג אווטר-תמונה עגול עם נפילה לאימוג'י; מסך החנות קורא את הקטלוג החי. **הצעד הבא: רותם מפיק תמונות באדמין ומפרסם — בלי בילד.**
- [סגור] פירוט מקורי:  מסך אדמין לאווטרים באותה מתכונת כמו הסקינים (גלריה, יצירת Gemini פר-פריט + batch, כיווץ <1MB, ייצוא ZIP לבייקינג / קטלוג חי), ואוסף אווטרים תלת-ממד איכותיים ויוקרתיים בדרגות לפי מחיר (בסיסי 50–150 / נדיר 300–500 / פרימיום 1000). בצד המשחק: אווטרים כתמונות (לא אימוג'י) — PlayerAvatar, חנות /store/avatars, הפצה בחדר דרך PlayerModel.avatarId. לתאם חוזה עם האדמין (FROM_GAME_PENDING) כשמתחילים.

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

### מודל התוכן (החלטת רוטם, 2026-07-04): אדמין חי + הטמעה בעדכון גרסה
- **האדמין שולט בזמן אמת, בלי עדכון גרסה:** `kBundledImagesOnly = false` (`content_manifest_service.dart`) — דריסות תמונה ומקומות remote חדשים שהאדמין מפרסם במניפסט מופיעים במשחק מיד (אחרי cache). `true` = בלם חירום בלבד (מתעלם מכל תמונת ענן; הסתרה/שמות/נושאים ממשיכים לעבוד).
- **בכל עדכון גרסה "אופים" את תוכן הענן פנימה** כדי לחסוך מקום/egress ב-Firestore/Storage. צ'קליסט שחרור:
  1. להוריד את התמונות של כל הפריטים במניפסט עם `imageUrl` פעיל (דריסות + remote) אל `assets/game_places/images/` בשמות לפי המוסכמה, ולעדכן/להוסיף רשומות ב-`assets/game_places/data/<category>.json`.
  2. לבנות ולהפיץ את הגרסה.
  3. **אחרי** שהגרסה בחוץ: באדמין — לנקות `imageUrl` מהדריסות שהוטמעו ולהעביר פריטי remote ל-`source:'bundled'` (או למחוק את הרשומה). הקליינט נופל אוטומטית לנכס המוטמע (`resolveBundled` מחזיר bundled כשאין override), ואפשר למחוק את הקבצים מ-Storage.
  - ⚠️ אל תנקו את המניפסט לפני שהגרסה החדשה זמינה — משתמשי הגרסה הישנה עדיין קוראים ממנו.
- **חוזה ZIP מהאדמין (v113+):** `overrides_manifest.json` יכול להכיל פריטים עם `new:true` — פריטים שקיימים רק בקטלוג האדמין (למשל ז'קט, קראטה) ואינם ב-JSON של המשחק. בבייקינג: מלבד העתקת התמונה, יש **להוסיף רשומה** ל-`assets/game_places/data/<category>.json` (סכימה: `id`/`name_he`/`answer_he`(=`answerHe`)/`aliases_he`/`category`/`difficulty`(ברירת מחדל easy)/`is_active:true`/`image_asset`). לפני v113 פריטים כאלה דולגו בשקט מהייצוא.

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
  - [ ] פוליש: אנימציות חשיפה/מחוון תור, אולי טיימר קצר לתור, בדיקה חיה על מכשיר (ביצועי ה-blur של 64 משבצות). ✔ מירוץ הצטרפות טופל (2026-07-11): joinRoom דוחה שחקן שלישי לחדר אותיות.
  - עדכוני 2026-07-11 נוספים: כיתוב גלובלי הוקטן 5% (main.dart, אחרי ה-clamp); קריסות מה-inbox תוקנו — AdShowError נבלע ב-fail-soft (ad_service), ושיתוף באייפד עבר ל-`shareText` (core/utils/share_util.dart) עם sharePositionOrigin בכל אתרי Share.

## זהו את הפתגם 🧩 (משחק חדש) — מומש (2026-07-10)
רבוס: תמונת 3D (סגנון פיקסאר, בלי טקסט) שרומזת על פתגם עברי. **רוכב במלואו על מנגנון חי-צומח-דומם**: חשיפה משבצת-משבצת, ניחוש במקלדת האותיות, ניקוד/בוטים/צ'אט/הצבעת-דילוג/מסך-ביניים — הכל מהתשתית הקיימת. **תמיד היט של 3 סבבים מקטגוריית `proverbs` בלבד** (בלי בחירת נושאים).
- **תוכן:** 24 פתגמים מוטמעים — `assets/game_places/data/proverbs.json` + תמונות `proverbs_<id>.jpg` (מיוצר מ-ZIP האדמין, מסך הפתגמים v158). `answer_he` = הפתגם (המוקלד); לפתגם הארוך `bird_in_hand` התשובה קוצרה ל"ציפור אחת ביד" (הנוסח המלא ב-name_he+aliases). `facts=[משמעות]` לעתיד. **תקרת התשובה: ≤24 אותיות מנורמלות** (נאכף בטסט `test/proverbs_content_test.dart`).
- **קוד:** קטגוריה `GameCategories.proverbs` (**לא** ב-`fastHeat` — לא נושא בחי-צומח-דומם ולא במשחק האותיות); `RoomModel.isProverbs` (נגזר מ-`selectedCategory=='proverbs'`, בלי mode חדש); `createRoom(heatTopics:)` להיט בנושא קבוע; `findMatchRoom(proverbs:)` מפריד התאמה ציבורית (+תיקון: מדלג על חדרי אותיות); חדר חברים בונה את ההיט ב-`startGameDirectly` (proverbs×3, מדלג על `_buildFriendsHeat`); הלובי מסתיר את בוחר הנושאים ואת דיאלוג "השלם ובחר"; rematch משמר את הקטגוריה; `LetterBankInput.maxLetters` (ברירת מחדל 12, פתגמים 24 — מילים נעטפות לשורות).
- **כניסה:** כפתור בית "🧩 זהו את הפתגם" (סגול) → אותו בורר "נגד מי?" (אקראי 2/3/4 עם כניסה 20 / חברים חינם).
- **חוזה אדמין:** קטגוריית `proverbs` במניפסט (id זהה) — פריטי remote עתידיים עם `category:'proverbs'` ייכנסו אוטומטית דרך `_loadLocalImages`. נרשם ב-FROM_GAME_PENDING.

## משחקים עתידיים — רעיונות (צ'קליסט)

## שיחת קול בחדרי חברים — נדחה (2026-07-11)
רותם ביקש שיחת ועידה קולית בחדרי חברים בלבד: השתקה כברירת מחדל, הפעלה בלחיצה ארוכה עם הסבר ואישור מראש. נדרש שירות WebRTC חיצוני (המלצה: Agora, 10,000 דקות חינם בחודש, אינטגרציה סבירה בפלאטר) — **דורש שרותם ייצור חשבון ב-agora.io ויעביר App ID**, בדיוק כמו מפתחות אפל/גוגל. רותם בחר לוותר בינתיים. כשירצה לחזור לזה: להתחיל בבקשת ה-App ID, ואז לתכנן UI (כפתור מיקרופון בלובי/משחק, רק ל-`room.isFriendsGame`), הרשאות מקורה (NSMicrophoneUsageDescription ב-iOS, RECORD_AUDIO באנדרואיד), וטרם הוחלט אם חלון ההסבר+אישור מוצג פעם ראשונה בלבד או בכל הפעלה.

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

### ✅ המסלול הקנוני: Codemagic (לא GitHub Actions)
ה-iOS נבנה ומועלה ל-TestFlight דרך **Codemagic** (`codemagic.yaml`, workflow `ios-testflight`), **לא** דרך build-ios.yml (זה מסלול legacy/גיבוי — ראה למטה).
- **טריגר:** דחיפת תג **`ios-v*`** (למשל `ios-v1`) מענף ההשקה → בונה IPA חתום ומעלה אוטומטית ל-TestFlight (`submit_to_testflight: true`). אפשר גם Start build ידני ב-Codemagic UI.
  ```bash
  git tag ios-v1 origin/claude/qa-launch-prep-EXqLn && git push origin ios-v1
  ```
- **חתימה:** אוטומטית ע"י Codemagic (`xcode-project use-profiles`), distribution_type=app_store, bundle `com.rotem.whoisthere`.
- **מפתח ASC:** integration ב-Codemagic בשם **בדיוק `Apple_Key_Trivia`** (Key ID 995PSX889V) — חייב להתאים ל-`codemagic.yaml`, אחרת "key not found".
- **build:** name `1.0.0`, number אוטומטי (`$PROJECT_BUILD_NUMBER`). כבר מטופל: שיטוח alpha באייקון, תיקון נתיב assets, תאימות gRPC/Firebase.
- **הקמה חד-פעמית + צעד-אחר-צעד:** `IOS_TESTFLIGHT_SETUP.md`.
- ⚠️ cowork לא יכול ללחוץ בממשק Codemagic — הוא דוחף תג `ios-v*` ומדריך את רותם לצעדים האנושיים (הוספת בודק ב-TestFlight וכו').

### (legacy) מסלול GitHub Actions
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
