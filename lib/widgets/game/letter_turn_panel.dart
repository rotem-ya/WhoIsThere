import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/letters_matcher.dart';
import 'letter_bank_input.dart' show kGeresh, normalizeHebrewFinals;

/// Turn-based Hangman-style letter guessing — an additive hint layer for the
/// main game modes (places / heat / proverbs), separate from both the
/// automatic tile reveal and the free-text guess race, and NOT the same
/// widget as the letters-duel screen (that mode is untouched by this file).
/// Each active player's turn they may guess ONE letter; every occurrence in
/// the answer reveals at once (final forms folded together), and the turn
/// always passes — hit or miss — after a guess or a 5s timeout.
class LetterTurnPanel extends StatefulWidget {
  final String answer;
  final Set<int> revealedSlots;
  final List<String> guessedLetters; // normalized forms already guessed this round
  final bool isMyTurn;
  final String turnPlayerName;
  final int? deadlineMs;
  final ValueChanged<String> onGuessLetter;

  const LetterTurnPanel({
    super.key,
    required this.answer,
    required this.revealedSlots,
    required this.guessedLetters,
    required this.isMyTurn,
    required this.turnPlayerName,
    required this.deadlineMs,
    required this.onGuessLetter,
  });

  @override
  State<LetterTurnPanel> createState() => _LetterTurnPanelState();
}

class _LetterTurnPanelState extends State<LetterTurnPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  Timer? _countdownTimer;
  int _remainingSec = 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _updateCountdown();
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) => _updateCountdown());
  }

  @override
  void dispose() {
    _glowController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    final deadline = widget.deadlineMs;
    final remaining = deadline == null
        ? 0
        : ((deadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, 5);
    if (remaining != _remainingSec && mounted) {
      setState(() => _remainingSec = remaining);
    }
  }

  void _tapLetter(String letter) {
    if (!widget.isMyTurn) return;
    HapticFeedback.mediumImpact();
    widget.onGuessLetter(letter);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.answer.isEmpty) return const SizedBox.shrink();
    final puzzle = buildLettersPuzzle(widget.answer);
    final guessedNorm = widget.guessedLetters.map(normalizeHebrewFinals).toSet();
    final answerNorm = puzzle.matchChars.map(normalizeHebrewFinals).toSet();

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF07101F).withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isMyTurn
                ? Color.lerp(const Color(0xFF2ECC71), const Color(0xFF9DFFC0),
                    _glowController.value)!
                : const Color(0xFFD4AF37).withOpacity(0.35),
            width: widget.isMyTurn ? 2.4 : 1.2,
          ),
          boxShadow: widget.isMyTurn
              ? [
                  BoxShadow(
                    color: const Color(0xFF2ECC71)
                        .withOpacity(0.25 + 0.35 * _glowController.value),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TurnBanner(
            isMyTurn: widget.isMyTurn,
            turnPlayerName: widget.turnPlayerName,
            remainingSec: _remainingSec,
          ),
          const SizedBox(height: 8),
          _LetterTurnSlots(puzzle: puzzle, revealedSlots: widget.revealedSlots),
          const SizedBox(height: 10),
          _LetterTurnKeyboard(
            enabled: widget.isMyTurn,
            glow: _glowController,
            guessedNorm: guessedNorm,
            answerNorm: answerNorm,
            onLetter: _tapLetter,
          ),
        ],
      ),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  final bool isMyTurn;
  final String turnPlayerName;
  final int remainingSec;

  const _TurnBanner({
    required this.isMyTurn,
    required this.turnPlayerName,
    required this.remainingSec,
  });

  @override
  Widget build(BuildContext context) {
    final text = isMyTurn ? 'התור שלך, בחר אות' : 'התור של $turnPlayerName';
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.rocket_launch_rounded,
          size: 16,
          color: isMyTurn ? const Color(0xFF2ECC71) : const Color(0xFFD4AF37),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isMyTurn ? const Color(0xFF9DFFC0) : const Color(0xFFFFE082),
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${remainingSec}s',
          style: TextStyle(
            color: isMyTurn ? const Color(0xFF9DFFC0) : Colors.white54,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _LetterTurnSlots extends StatelessWidget {
  final LettersPuzzle puzzle;
  final Set<int> revealedSlots;

  const _LetterTurnSlots({required this.puzzle, required this.revealedSlots});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        const slotGap = 5.0;
        const wordGap = 12.0;
        final totalLetters = math.max(1, puzzle.length);
        final wordCount = math.max(1, puzzle.wordLengths.length);
        final totalGapWidth = slotGap * (totalLetters - wordCount) + wordGap * (wordCount - 1);
        final slotSize =
            math.min(34.0, math.max(18.0, (constraints.maxWidth - 8 - totalGapWidth) / totalLetters));
        var idx = 0;
        final words = <Widget>[];
        for (final len in puzzle.wordLengths) {
          final slots = <Widget>[];
          for (var i = 0; i < len; i++) {
            if (i > 0) slots.add(const SizedBox(width: slotGap));
            final revealed = idx < puzzle.length && revealedSlots.contains(idx);
            final letter = revealed ? puzzle.displayChars[idx] : null;
            slots.add(_LetterTurnSlot(letter: letter, size: slotSize));
            idx++;
          }
          words.add(Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: slots));
        }
        return Wrap(
          textDirection: TextDirection.rtl,
          alignment: WrapAlignment.center,
          spacing: wordGap,
          runSpacing: 6,
          children: words,
        );
      });
}

class _LetterTurnSlot extends StatelessWidget {
  final String? letter;
  final double size;

  const _LetterTurnSlot({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    final filled = letter != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(
                colors: [Color(0xFF9DFFC0), Color(0xFF2ECC71)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: filled ? null : const Color(0xFF07101F),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: filled ? const Color(0xFF9DFFC0) : const Color(0xFFD4AF37).withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Text(
        letter ?? '',
        style: TextStyle(
          color: const Color(0xFF07101F),
          fontSize: math.max(11, size * 0.55),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

// Same 22-letter + 5-final-form + geresh layout as the free-text keyboard
// (letter_bank_input.dart) and the letters duel — duplicated rather than
// shared so this new, still-settling mechanic can never regress either of
// those already-live keyboards.
const List<List<String>> _letterTurnKeyboardRows = [
  ['פ', 'ם', 'ן', 'ו', 'ט', 'א', 'ר', 'ק'],
  ['ף', 'ך', 'ל', 'ח', 'י', 'ע', 'כ', 'ג', 'ד', 'ש'],
  ['ץ', 'ת', 'צ', 'מ', 'נ', 'ה', 'ב', 'ס', 'ז', kGeresh],
];

class _LetterTurnKeyboard extends StatelessWidget {
  final bool enabled;
  final Animation<double> glow;
  final Set<String> guessedNorm;
  final Set<String> answerNorm;
  final ValueChanged<String> onLetter;

  const _LetterTurnKeyboard({
    required this.enabled,
    required this.glow,
    required this.guessedNorm,
    required this.answerNorm,
    required this.onLetter,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        const gap = 4.0;
        const maxKeysInRow = 10;
        final keySize =
            math.min(34.0, math.max(20.0, (constraints.maxWidth - gap * (maxKeysInRow - 1)) / maxKeysInRow));
        // Nested AnimatedBuilder: only the tappable keys' glow needs to
        // repaint every tick, not the whole panel (that's the outer one).
        return AnimatedBuilder(
          animation: glow,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _letterTurnKeyboardRows.length; i++) ...[
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final letter in _letterTurnKeyboardRows[i])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _LetterTurnKey(
                          label: letter,
                          size: keySize,
                          status: _statusFor(letter),
                          glowValue: glow.value,
                          onTap: () => onLetter(letter),
                        ),
                      ),
                  ],
                ),
                if (i != _letterTurnKeyboardRows.length - 1) const SizedBox(height: 6),
              ],
            ],
          ),
        );
      });

  _LetterKeyStatus _statusFor(String letter) {
    final norm = normalizeHebrewFinals(letter);
    if (!guessedNorm.contains(norm)) {
      return enabled ? _LetterKeyStatus.tappable : _LetterKeyStatus.waiting;
    }
    return answerNorm.contains(norm) ? _LetterKeyStatus.hit : _LetterKeyStatus.miss;
  }
}

enum _LetterKeyStatus { tappable, waiting, hit, miss }

class _LetterTurnKey extends StatelessWidget {
  final String label;
  final double size;
  final _LetterKeyStatus status;
  // 0..1 pulse phase, only meaningful (and only animating) for a tappable
  // key — this is the literal "keyboard lit up in glowing green" signal for
  // whose turn it is, on the keys themselves, not just the panel border.
  final double glowValue;
  final VoidCallback onTap;

  const _LetterTurnKey({
    required this.label,
    required this.size,
    required this.status,
    required this.glowValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = status == _LetterKeyStatus.tappable;
    Color bg;
    Color fg;
    Border border;
    List<BoxShadow>? shadow;
    switch (status) {
      case _LetterKeyStatus.tappable:
        bg = Color.lerp(const Color(0xFF2ECC71), const Color(0xFF9DFFC0), glowValue)!;
        fg = const Color(0xFF07101F);
        border = Border.all(
            color: Color.lerp(const Color(0xFF9DFFC0), Colors.white, glowValue)!,
            width: 1.6);
        shadow = [
          BoxShadow(
            color: const Color(0xFF2ECC71).withOpacity(0.35 + 0.35 * glowValue),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ];
        break;
      case _LetterKeyStatus.waiting:
        bg = Colors.white.withOpacity(0.55);
        fg = Colors.grey.shade600;
        border = Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1);
        break;
      case _LetterKeyStatus.hit:
        bg = const Color(0xFF2ECC71);
        fg = const Color(0xFF07101F);
        border = Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1);
        break;
      case _LetterKeyStatus.miss:
        bg = Colors.white.withOpacity(0.14);
        fg = Colors.white38;
        border = Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1);
        break;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tappable ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: size,
          height: size + 8,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border,
            boxShadow: shadow,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: math.max(14, size * 0.5),
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
