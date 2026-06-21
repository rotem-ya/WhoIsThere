import 'package:flutter_test/flutter_test.dart';
import 'package:whois_there/core/utils/letters_matcher.dart';

void main() {
  group('buildLettersPuzzle', () {
    test('single word folds finals and keeps display chars', () {
      final p = buildLettersPuzzle('חתול');
      expect(p.length, 4);
      expect(p.matchChars, ['ח', 'ת', 'ו', 'ל']);
      expect(p.wordLengths, [4]);
    });

    test('final letters are folded for matching but shown as-is', () {
      // עורב? use a word ending in a sofit: "ירוק" no sofit; use "חלון" → ן
      final p = buildLettersPuzzle('חלון');
      expect(p.displayChars, ['ח', 'ל', 'ו', 'ן']);
      expect(p.matchChars, ['ח', 'ל', 'ו', 'נ']); // ן folded to נ
    });

    test('multi-word: lengths per word, spaces dropped', () {
      final p = buildLettersPuzzle('אדום החזה');
      expect(p.wordLengths, [4, 4]);
      expect(p.length, 8);
      expect(p.matchChars.contains(' '), isFalse);
    });

    test('geresh stripped (ג\'ירפה -> גירפה)', () {
      final p = buildLettersPuzzle("ג'ירפה");
      expect(p.length, 5);
      expect(p.matchChars.first, 'ג');
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

    test('final-form guess matches folded slot', () {
      final pn = buildLettersPuzzle('חלון'); // slot 3 = ן -> נ
      // guessing the non-final נ at slot 3 should be exact
      expect(evaluateGuess(pn, 3, 'נ'), LetterFeedback.exact);
      // guessing the final ן should also normalize and be exact
      expect(evaluateGuess(pn, 3, 'ן'), LetterFeedback.exact);
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

    test('present: guessed, in word, not yet locked anywhere', () {
      expect(keyStatusFor(p, 'ת', const {}, {'ת'}), KeyStatus.present);
    });
  });
}
