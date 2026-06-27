import 'dart:math' as math;

import '../../widgets/game/letter_bank_input.dart' show canonicalizeGeresh;

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

/// The letters board is a fixed 8×8 grid of frosted-glass tiles (independent of
/// the [Difficulty] grid sizes).
const int kLettersGridSize = 8;

enum LetterFeedback { exact, present, absent }

/// A prepared puzzle: one entry per letter slot, aligned across the three lists.
/// Matching is EXACT per letter form: a base letter (e.g. מ) and its final form
/// (ם) are distinct, so guessing one never marks the other. [displayChars] and
/// [matchChars] are therefore identical (the canonical letter, with geresh kept
/// as its own slot); both are retained so callers stay explicit about intent.
/// [wordLengths] drives the multi-word slot layout.
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
/// canonicalizing geresh (kept as a real slot), and capping at
/// [kLettersMaxSlots]. Letter forms are kept EXACT (no final-letter folding),
/// so each slot must be guessed with its precise letter. The slot index used
/// everywhere else refers to a position in the returned (space-free) lists.
LettersPuzzle buildLettersPuzzle(String answer) {
  final words = canonicalizeGeresh(answer)
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  final chars = <String>[];
  final wordLengths = <int>[];
  var total = 0;
  for (final word in words) {
    if (total >= kLettersMaxSlots) break;
    // Hebrew letters and the geresh are single BMP code units, so a plain
    // split is safe here.
    final wordChars = word.split('');
    final allowed = math.min(wordChars.length, kLettersMaxSlots - total);
    if (allowed <= 0) continue;
    var added = 0;
    for (var i = 0; i < allowed; i++) {
      final ch = wordChars[i];
      if (ch.trim().isEmpty) continue;
      chars.add(ch);
      added++;
    }
    if (added > 0) {
      wordLengths.add(added);
      total += added;
    }
  }
  return LettersPuzzle(
    // Matching is exact, so the display and match lists are the same letters.
    displayChars: List<String>.of(chars),
    matchChars: chars,
    wordLengths: wordLengths.isEmpty ? const [1] : wordLengths,
  );
}

/// Feedback for guessing [guessedLetter] at [slotIndex]. Matching is exact —
/// only geresh marks are canonicalized; base and final letter forms are
/// distinct, so guessing מ never matches a ם slot.
LetterFeedback evaluateGuess(
  LettersPuzzle puzzle,
  int slotIndex,
  String guessedLetter,
) {
  final g = canonicalizeGeresh(guessedLetter).trim();
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
/// canonical (geresh-normalized) forms the player has tried.
KeyStatus keyStatusFor(
  LettersPuzzle puzzle,
  String letter,
  Set<int> solvedSlots,
  Set<String> guessedLetters,
) {
  final g = canonicalizeGeresh(letter).trim();
  for (final s in solvedSlots) {
    if (s >= 0 && s < puzzle.length && puzzle.matchChars[s] == g) {
      return KeyStatus.solved;
    }
  }
  if (!guessedLetters.contains(g)) return KeyStatus.neutral;
  return puzzle.matchChars.contains(g) ? KeyStatus.present : KeyStatus.absent;
}
