# פיצ'רי engagement — גלגל מזל / משימה יומית / טבלה שבועית

שלושה פיצ'רים שנוספו על ענף `claude/whoishere-visual-sound-rjcdzb`. כולם רוכבים על
מודל הכלכלה הקיים (טרנזקציות client-side ל-Firestore, client-trusted כמו הפרס היומי).

## 1. גלגל מזל יומי
- שדה חדש בארנק: `users/{uid}/economy/wallet.lastDailySpinAt`.
- `EconomyService.claimDailySpin` — סיבוב אחד ליום UTC, פרס לפי משקלים
  (`EconomyConfig.dailySpinSegments/Weights`), טרנזקציה `dailySpin`.
- **אין שינוי חוקי Firestore** (כתיבה עצמית לארנק כבר מותרת). **אין עבודת אדמין.**

## 2. משימה יומית
- מסמך חדש: `users/{uid}/economy/daily_quest` = `{dayKey, index, baseline, claimed}`.
  מכוסה בכלל `economy/{document}` הקיים (owner read/write) — **אין שינוי rules.**
- התקדמות = דלתת מונה-חיים (`totalMatchesWon`/`totalMatchesPlayed`/`discoveredImageIds.length`)
  מאז baseline. טרנזקציה `dailyQuest`. **אין עבודת אדמין.**

## 3. טבלת מובילים שבועית ⚠️ דורש פריסת rules
- אוסף חדש: `leaderboards/weekly_{weekKey}/entries/{uid}` (`{name, photoUrl, points, updatedAt}`)
  + `leaderboards/weekly_{weekKey}/claims/{uid}` לפרס פודיום.
- כל שבוע ISO = אוסף נפרד (בלי קרון/איפוס). כל קליינט כותב **רק את הרשומה שלו**;
  קריאה פתוחה ל-signedIn. דירוג עצמי דרך aggregate `count()`.
- פרס פודיום שבוע שעבר: 100/50/25 מטבעות, אידמפוטנטי דרך claims doc.
- ניקוד נרשם ב-`_triggerMatchReward` (game_board_screen) — פעם אחת לכל משחק, כל המצבים.

### ⚠️ קריטי לפני שהפיצ'ר עובד
נוספו חוקים ל-`firestore.rules` (בלוק `match /leaderboards/{board}`). **חוקי Firestore
נפרסים רק מ-`main`** דרך `deploy-firestore-rules.yml`. עד שהחוקים החדשים ב-main ונפרסו,
כתיבות ל-`leaderboards/**` **נדחות** (ה-catch-all חוסם). לכן: למזג את שינוי ה-rules ל-main
(או להריץ את ה-workflow) לפני/בסמוך לשחרור הגרסה שכוללת את הטבלה השבועית.

### חוזה אדמין (לרישום ב-FROM_GAME_PENDING של ריפו האדמין)
- אוסף חדש `leaderboards/**` (קריאה ציבורית ל-signedIn). אם האדמין ירצה לצפות/למחוק —
  להוסיף גישת admin. כרגע אין תלות אדמין לתפעול.
- הערת אמון: הניקוד השבועי client-written (כמו `friendsGamePoints`). מתאים למטבע-משחק.
  אם בעתיד רוצים אכיפה חזקה — לעבור ל-Cloud Function שכותב את הניקוד.
