import 'dart:math' as math;

import '../../widgets/game/letter_bank_input.dart'
    show stripGeresh, normalizeHebrewFinals;

/// Pure logic for the letters game (משחק האותיות) — a Wordle-style per-slot
/// letter duel. No Flutter/UI dependencies so it stays trivially testable.
///
/// A turn = "guess a letter for a chosen slot":
///  - the letter is the correct one at that slot  → [LetterFeedback.exact]   → 4 tiles, slot locks
///  - the letter exists elsewhere in the word       → [LetterFeedback.present] → 2 tiles
///  - the letter is not in the word                 → [LetterFeedback.absent]  → 0 tiles
/// A player wins when every slot is locked (solved).

/// Max number of letter slots a puzzle can have (mirrors [LetterBankInput]'s
/// 12-slot cap so the on-screen layout never overflows).
const int kLettersMaxSlots = 12;

enum LetterFeedback { exact, present, absent }

/// A prepared puzzle: one entry per letter slot, aligned across the three lists.
/// [displayChars] keeps the original (geresh-stripped) letter for showing in a
/// solved slot; [matchChars] is the normalized form (finals folded) used for
/// all comparisons. [wordLengths] drives the multi-word slot layout.
class LettersPuzzle {
  final List<String> displayChars;
  final List<String> matchChars;
  final List<int> wordLengths;

  const LettersPuzzle({
    required this.displayChars,
    required this.matchChars,
    required this.wordLengths,
  });

  int get length => matchChars.length;

  /// The distinct normalized letters that actually appear in the answer.
  Set<String> get answerLetters => matchChars.toSet();
}

/// Builds a puzzle from a Hebrew answer, splitting on whitespace into words,
/// stripping geresh, folding final letters, and capping at [kLettersMaxSlots].
/// The slot index used everywhere else refers to a position in the returned
/// (space-free) lists.
LettersPuzzle buildLettersPuzzle(String answer) {
  final words = stripGeresh(answer)
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final display = <String>[];
  final match = <String>[];
  final wordLengths = <int>[];
  var total = 0;
  for (final word in words) {
    if (total >= kLettersMaxSlots) break;
    // Hebrew letters are single BMP code units, so a plain split is safe here
    // (geresh marks were already stripped above).
    final chars = word.split('');
    final allowed = math.min(chars.length, kLettersMaxSlots - total);
    if (allowed <= 0) continue;
    var added = 0;
    for (var i = 0; i < allowed; i++) {
      final ch = chars[i];
      final norm = normalizeHebrewFinals(ch);
      // normalizeHebrewFinals also drops spaces; skip if the char vanished.
      if (norm.isEmpty) continue;
      display.add(ch);
      match.add(norm);
      added++;
    }
    if (added > 0) {
      wordLengths.add(added);
      total += added;
    }
  }
  return LettersPuzzle(
    displayChars: display,
    matchChars: match,
    wordLengths: wordLengths.isEmpty ? const [1] : wordLengths,
  );
}

/// Feedback for guessing [guessedLetter] at [slotIndex].
LetterFeedback evaluateGuess(
  LettersPuzzle puzzle,
  int slotIndex,
  String guessedLetter,
) {
  final g = normalizeHebrewFinals(guessedLetter);
  if (g.isEmpty) return LetterFeedback.absent;
  if (slotIndex >= 0 &&
      slotIndex < puzzle.length &&
      puzzle.matchChars[slotIndex] == g) {
    return LetterFeedback.exact;
  }
  return puzzle.matchChars.contains(g)
      ? LetterFeedback.present
      : LetterFeedback.absent;
}

/// Image tiles to reveal for a given feedback: exact → 4, present → 2, absent → 0.
int tilesForFeedback(LetterFeedback feedback) {
  switch (feedback) {
    case LetterFeedback.exact:
      return 4;
    case LetterFeedback.present:
      return 2;
    case LetterFeedback.absent:
      return 0;
  }
}

/// A player has solved the puzzle when every slot is locked.
bool isPuzzleComplete(LettersPuzzle puzzle, Set<int> solvedSlots) =>
    puzzle.length > 0 && solvedSlots.length >= puzzle.length;

/// On-screen keyboard coloring for a single key.
enum KeyStatus { neutral, solved, present, absent }

/// Status of [letter] given the player's solved slots and guessed letters
/// (both relative to this player's own board). [guessedLetters] must be the
/// normalized forms the player has tried.
KeyStatus keyStatusFor(
  LettersPuzzle puzzle,
  String letter,
  Set<int> solvedSlots,
  Set<String> guessedLetters,
) {
  final g = normalizeHebrewFinals(letter);
  for (final s in solvedSlots) {
    if (s >= 0 && s < puzzle.length && puzzle.matchChars[s] == g) {
      return KeyStatus.solved;
    }
  }
  if (!guessedLetters.contains(g)) return KeyStatus.neutral;
  return puzzle.matchChars.contains(g) ? KeyStatus.present : KeyStatus.absent;
}
