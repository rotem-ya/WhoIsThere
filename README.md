# WhoIsThere — Developer Notes

> קרא קובץ זה לפני שמתחילים לעבוד. מכיל תובנות קריטיות שנלמדו בדרך הקשה.

---

## מבנה המשחק

אפליקציית Flutter (אנדרואיד/iOS) — ניחוש מקומות בישראל מתמונה מגולה בהדרגה.

### מסכים ראשיים
| מסך | קובץ | הערות |
|-----|------|--------|
| בית | `screens/home/home_screen.dart` | כניסה למשחק, חנות, פרופיל |
| לובי | `screens/lobby/lobby_screen.dart` | המתנה לשחקנים |
| משחק | `screens/game/game_board_screen.dart` | המסך הראשי — 2000+ שורות |
| חנות | `screens/store/store_screen.dart` | 3 טאבים: רכישה / כרטיסים / עיצובים |
| פרופיל | `screens/profile/profile_screen.dart` | סטטיסטיקות ודירוג |

---

## ⚠️ תובנות קריטיות — לא לחזור על הטעויות האלה

### 1. isSolo — הטעות הנפוצה ביותר

`isSolo = true` כשיש **שחקן אנושי אחד בלבד**, גם אם יש בוטים.
**כמעט כל משחק הוא סולו.** (1 אדם + 1-3 בוטים)

אם שמת `!isSolo` כתנאי לפיצ'ר — הפיצ'ר לא יעבוד לרוב המשתמשים.

```dart
// ❌ שגוי — חוסם סולו (= כמעט הכל)
final canUseStunCard = !isSolo && stunCardCount > 0 ...

// ✅ נכון
final canUseStunCard = stunCardCount > 0 && stunTargets.isNotEmpty ...
```

### 2. !isBot על targets — הטעות הזוגית

```dart
// ❌ שגוי — בוטים לא ניתנים לטרגוט
players.where((p) => !p.isBot && !isSolo ...).toList();

// ✅ נכון — כרטיסים עובדים גם על בוטים
players.where((p) => !p.isEliminated && p.id != myId).toList();
```

### 3. אחרי שינוי בלוגיקת Guard — לבדוק ידנית

לאחר כל שינוי ב-`canUse*` / `_canTarget` / `enabled` — לשאול:
- **האם עובד בסולו (בוט)?** זה המקרה הנפוץ.
- **האם עובד במולטיפלייר?**
- **האם הסרת guard לא שבר הגנה אחרת?**

### 4. wallet — אסור לקרוא `ref.invalidate(localEconomyCacheProvider)`

`walletProvider` הוא StreamProvider שמסתנכרן אוטומטית עם Firestore.
קריאת `ref.invalidate(localEconomyCacheProvider)` גרמה למסך שחור.

```dart
// ❌ גרם למסך שחור אחרי פרס יומי
ref.invalidate(localEconomyCacheProvider);

// ✅ לא צריך כלום — הסטרים מתעדכן לבד
setState(() { _claimed = true; });
```

### 5. FittedBox בלי אילוץ רוחב

```dart
// ❌ לא מצליח לדחוס — כיתוב בורח
Center(child: FittedBox(child: Text(...)))

// ✅ נכון
SizedBox(
  width: double.infinity,
  child: FittedBox(fit: BoxFit.scaleDown, child: Text(...)),
)
```

### 6. Snackbar מצטבר בלחיצות חוזרות

```dart
// ✅ תמיד
ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(...));
```

---

## כרטיסי פעולה — זרם מלא

```
חנות (store_screen.dart)
  └─ _CardsTab → _PlayingCard → _buyCard()
       ├─ economy.buyStunCard(uid)
       ├─ economy.buyGuessBlock5Card(uid)
       ├─ economy.buyGuessBlock10Count(uid)
       └─ economy.buyBlackoutCard(uid)

במשחק — שני מסלולים:

מסלול A: כרטיס עצור
  game_board_screen → GameLayout (stunCardCount, onStunCard)
  → GameActions → _StunCardButton → AlertDialog (בחר יעד)
  → onStunCard(targetId) → room_service.applyStunCard()

מסלול B: חסימה + החשכה
  game_top_hud → _PlayerCell.onTap → _showActionSheet()
  → _PlayerActionSheet → room_service.applyGuessBlockCard() / applyBlackoutCard()
```

תנאים להפעלה (`game_layout.dart`):
- `stunCardCount > 0`
- `stunTargets.isNotEmpty` (לא אלימינייטד, לא אני)
- `turnPhase != guessMode`
- `phase != finished`

---

## מערכת סקינים

**שני מקורות:**

| מקור | קובץ | מתי פעיל |
|------|------|----------|
| Hardcoded | `models/card_skin.dart` → `kAvailableCardSkins` | תמיד כ-fallback |
| Firestore | `providers/skin_providers.dart` → `firestoreSkinsProvider` | כש-`card_skins` collection לא ריקה |

**שדות Firestore לסקין:**
```json
{
  "nameHe": "שם",
  "price": 30,
  "active": true,
  "sortOrder": 0,
  "coverImageUrl": "https://...",
  "previewImageUrl": "https://..."
}
```

**סדר טעינת תמונה** (`vault_cover.dart`):
1. `coverImageUrl` → HTTP → `ui.Image`
2. `assetPath` → asset bundle → `ui.Image`
3. ללא תמונה → color palette + pattern ייחודי לכל סקין

---

## תמונות משחק — עדיין local

נטען מ: `assets/game_places/data/israel_places.json`
קוד: `RoomService._readLocalImages()`

**לא קורא מ-Firestore** — כשהאדמין יוסיף ל-`game_images`, יש לעדכן `RoomService`.

9 מקומות פעילים כרגע:
`western_wall, dome_of_the_rock, tower_of_david, knesset, israel_museum, yad_vashem, masada, dead_sea, ein_gedi`

---

## מבנה Firestore

```
users/{uid}
  ├─ economy/wallet              coins, totalEarned, streak
  ├─ economy_transactions/       היסטוריה
  ├─ name, selectedCardSkin, ownedSkins
  ├─ stunCardCount, guessBlock5Count, guessBlock10Count, blackoutCardCount
  └─ totalPoints, discoveredImageIds

rooms/{roomId}
  ├─ players/{uid}               PlayerModel
  ├─ phase, turnPhase, currentTurnUserId
  ├─ placedPieces, availablePieceIndices
  ├─ blockedGuessers             {uid: revealCount}
  ├─ guessBlockedUntilMs         {uid: timestamp}
  ├─ blackoutActiveUntilMs       {uid: timestamp}
  └─ cardSkinId                  skin המארח

card_skins/{skinId}              סקינים מהאדמין
game_images/{imageId}            תמונות מהאדמין (עתידי)
```

**Firebase Project:** `whoisthere-380fa`
**Storage bucket:** `whoisthere-380fa.firebasestorage.app`

---

## build label

`lib/core/constants/build_info.dart` → `kBuildLabel`
פורמט: `build-YYYYMMDD-תיאור-rN`
מוצג בפרופיל — ככה מאמתים שהAPK הנכון מותקן.

---

## CI/CD

Push ל-`claude/**` → GitHub Actions → APK אוטומטי.
Push רק אחרי 5 משימות או בסיום כל המטלות.

---

## טבלת שגיאות שקרו

| שגיאה | תוצאה | תיקון |
|-------|-------|-------|
| `!isSolo` על כרטיסים | כרטיסים מושבתים לכולם | הסר את guard הסולו |
| `!p.isBot` על targets | בוטים לא ניתנים לטרגוט | אפשר לטרגט בוטים |
| `ref.invalidate(localEconomyCacheProvider)` | מסך שחור | הסר — הסטרים מתעדכן לבד |
| `FittedBox` ב-`Center` | כיתוב חורג | עטוף ב-`SizedBox(width: infinity)` |
| `showSnackBar` חוזר | הודעות מצטברות | קרא `hideCurrentSnackBar()` לפני |
| פיצ'ר "בוצע" בלי בדיקה | לא עובד בפועל | תמיד בדוק: סולו? בוט? מולטיפלייר? |
