# פרומפט לסשן "Claude REDESIGN" — סנכרון לפני תחילת שלב 0

לפני שמתחילים לכתוב קוד על ענף `claude/whoishere-visual-sound-rjcdzb`, יש עוד סשן Claude Code שעובד במקביל על אותו ריפו (ענף `claude/whothere-v111-launch-iqkbq2`) - היום עלו משם: תיקון חירום ל-v1.3.2 (השבתת פאנל ניחוש-אותיות שכיווץ את תמונת המשחק), מעקב חברים-בוט לבדיקות, ושיפורים נוספים. כל זה כבר מוזג ל-`main`.

## שלב 1 - סנכרון לפני שמתחילים
```bash
git fetch origin main
git checkout claude/whoishere-visual-sound-rjcdzb   # או git checkout -b אם עוד לא נוצר מקומית
git merge origin/main --no-edit
```
אם יש קונפליקטים - הם צפויים בעיקר בקבצים הבאים (גם אני עלול לגעת בהם בהמשך): `lib/screens/game/game_board_screen.dart`, `lib/screens/game/widgets/game_layout.dart`, `lib/screens/room/lobby_screen.dart`, `lib/screens/friends/friends_screen.dart`. בכל קונפליקט - לשמור את שני הצדדים כשאפשר (שלי הן תוספות פיצ'ר/באגפיקס, שלך הן שינויי עיצוב/סאונד), לא לדרוס בטעות.

**חשוב:** תריץ `flutter analyze` ו-`flutter test` אחרי הסנכרון, לפני שמתחילים לכתוב קוד חדש - כדי לוודא שאתם מתחילים מבסיס ירוק.

## שלב 2 - במהלך העבודה
אל תמתינו לסוף הפרויקט כדי לסנכרן שוב. כל כמה ימים (או לפני כל push משמעותי): לחזור על שלב 1 (fetch + merge origin/main). ככה שני הענפים לא מתרחקים אחד מהשני לנקודה שהמיזוג הסופי הופך לכואב.

## שלב 3 - בסיום כל שלב (0, 1, 2...)
לדחוף את הענף (`git push origin claude/whoishere-visual-sound-rjcdzb`), ולעדכן את רותם - אני אבצע מיזוג תקופתי חזרה ל-`main` מהצד שלי, לא צריך לחכות לסוף כל הפרויקט.

בהצלחה בשלב 0.
