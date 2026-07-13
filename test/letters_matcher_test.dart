import 'package:flutter_test/flutter_test.dart';
import 'package:whois_there/core/utils/letters_matcher.dart';

void main() {
  group('buildLettersPuzzle', () {
    test('single word keeps exact chars', () {
      final p = buildLettersPuzzle('חתול');
      expect(p.length, 4);
      expect(p.matchChars, ['ח', 'ת', 'ו', 'ל']);
      expect(p.wordLengths, [4]);
    });

    test('final letters are kept exact (no folding)', () {
      final p = buildLettersPuzzle('חלון');
      expect(p.displayChars, ['ח', 'ל', 'ו', 'ן']);
      expect(p.matchChars, ['ח', 'ל', 'ו', 'ן']); // ן stays ן (distinct from נ)
    });

    test('multi-word: lengths per word, spaces dropped', () {
      final p = buildLettersPuzzle('אדום החזה');
      expect(p.wordLengths, [4, 4]);
      expect(p.length, 8);
      expect(p.matchChars.contains(' '), isFalse);
    });

    test("geresh kept as a real slot (ג'ירפה)", () {
      final p = buildLettersPuzzle("ג'ירפה");
      expect(p.length, 6); // ג ' י ר פ ה
      expect(p.matchChars, ['ג', "'", 'י', 'ר', 'פ', 'ה']);
    });

    test('hebrew geresh ׳ canonicalized to apostrophe slot (צ׳ילה)', () {
      final p = buildLettersPuzzle('צ׳ילה');
      expect(p.length, 5); // צ ' י ל ה
      expect(p.matchChars, ['צ', "'", 'י', 'ל', 'ה']);
    });
  });

  group('evaluateGuess + tiles', () {
    final p = buildLettersPuzzle('חתול');

    test('exact position -> 4 tiles', () {
      final f = evaluateGuess(p, 0, 'ח');
      expect(f, LetterFeedback.exact);
      expect(tilesForFeedback(f), 4);
    });

    test('present but wrong slot -> 2 tiles', () {
      final f = evaluateGuess(p, 0, 'ת'); // ת is at slot 1, not 0
      expect(f, LetterFeedback.present);
      expect(tilesForFeedback(f), 2);
    });

    test('absent -> 0 tiles', () {
      final f = evaluateGuess(p, 0, 'ר');
      expect(f, LetterFeedback.absent);
      expect(tilesForFeedback(f), 0);
    });

    test('base and final forms are distinct', () {
      final pn = buildLettersPuzzle('חלון'); // slot 3 = ן (final form)
      // guessing the exact final ן at slot 3 is exact
      expect(evaluateGuess(pn, 3, 'ן'), LetterFeedback.exact);
      // guessing the base נ must NOT match — נ is not in the word at all
      expect(evaluateGuess(pn, 3, 'נ'), LetterFeedback.absent);
    });

    test('geresh slot is guessed with the apostrophe key', () {
      final pg = buildLettersPuzzle("ג'ירפה"); // slot 1 = '
      expect(evaluateGuess(pg, 1, "'"), LetterFeedback.exact);
      expect(evaluateGuess(pg, 1, '׳'), LetterFeedback.exact); // canonicalized
    });
  });

  group('completion + keyboard status', () {
    final p = buildLettersPuzzle('חתול');

    test('isPuzzleComplete when all slots solved', () {
      expect(isPuzzleComplete(p, {0, 1, 2}), isFalse);
      expect(isPuzzleComplete(p, {0, 1, 2, 3}), isTrue);
    });

    test('key status: solved / present / absent / neutral', () {
      final solved = {0}; // ח solved at slot 0
      final guessed = {'ח', 'ר'}; // ח tried (in word), ר tried (absent)
      expect(keyStatusFor(p, 'ח', solved, guessed), KeyStatus.solved);
      expect(keyStatusFor(p, 'ר', solved, guessed), KeyStatus.absent);
      expect(keyStatusFor(p, 'ת', solved, guessed), KeyStatus.neutral); // not yet guessed
    });

    test('final-form key is independent of its base form', () {
      final pn = buildLettersPuzzle('חלון'); // has ן, not נ
      // The base נ was guessed and is absent; the final ן key stays neutral.
      expect(keyStatusFor(pn, 'נ', const {}, {'נ'}), KeyStatus.absent);
      expect(keyStatusFor(pn, 'ן', const {}, {'נ'}), KeyStatus.neutral);
    });

    test('present: guessed, in word, not yet locked anywhere', () {
      expect(keyStatusFor(p, 'ת', const {}, {'ת'}), KeyStatus.present);
    });
  });

  group('matchAllSlotsForLetter (main-game letter-turn mechanic)', () {
    test('single occurrence returns that one slot', () {
      final p = buildLettersPuzzle('חתול');
      expect(matchAllSlotsForLetter(p, 'ח'), {0});
    });

    test('multiple occurrences return all matching slots at once', () {
      final p = buildLettersPuzzle('בננה');
      expect(matchAllSlotsForLetter(p, 'נ'), {1, 2});
    });

    test('zero occurrences returns an empty set', () {
      final p = buildLettersPuzzle('חתול');
      expect(matchAllSlotsForLetter(p, 'ז'), isEmpty);
    });

    test('geresh guess matches a geresh slot', () {
      final p = buildLettersPuzzle("ג'ירפה");
      expect(matchAllSlotsForLetter(p, "'"), {1});
      expect(matchAllSlotsForLetter(p, '׳'), {1}); // canonicalized geresh mark
    });

    test('multi-word answer matches across both words', () {
      final p = buildLettersPuzzle('אדום החזה'); // א ד ו ם | ה ח ז ה
      expect(matchAllSlotsForLetter(p, 'ה'), {4, 7});
    });

    test('final-form folding: base guess matches a final-form slot', () {
      final p = buildLettersPuzzle('חלון'); // slot 3 = ן
      expect(matchAllSlotsForLetter(p, 'נ'), {3});
    });

    test('final-form folding: final-form guess matches a base-form slot', () {
      final p = buildLettersPuzzle('בננה'); // slots 1,2 = נ (base)
      expect(matchAllSlotsForLetter(p, 'ן'), {1, 2});
    });

    test('empty/whitespace guess returns an empty set', () {
      final p = buildLettersPuzzle('חתול');
      expect(matchAllSlotsForLetter(p, ''), isEmpty);
      expect(matchAllSlotsForLetter(p, '   '), isEmpty);
    });
  });
}
