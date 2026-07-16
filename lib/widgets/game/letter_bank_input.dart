import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../economy/coin_icon.dart';

/// The single canonical geresh the geresh key inserts. The content data spells
/// words like ג'ירפה inconsistently (Hebrew ׳ or an ASCII apostrophe), so every
/// mark is canonicalized to this one form for both the slots and comparisons.
const String kGeresh = "'";

/// Canonicalizes geresh / gershayim marks (Hebrew ׳ ״ and ASCII ' ") to
/// [kGeresh] — it KEEPS the mark (does not strip it) so a word like ג'ירפה
/// keeps its geresh as a real, type-able slot.
String canonicalizeGeresh(String s) => s
    .replaceAll('׳', kGeresh) // ׳ Hebrew punctuation geresh
    .replaceAll('״', kGeresh) // ״ Hebrew punctuation gershayim
    .replaceAll('"', kGeresh) // ASCII quote
    .replaceAll("'", kGeresh); // ASCII apostrophe (already canonical)

/// Removes geresh / gershayim marks entirely. Kept for the forgiving place-name
/// match (so גירפה and ג'ירפה compare equal there); the letter games use
/// [canonicalizeGeresh] instead so the geresh stays a real slot.
String stripGeresh(String s) => s
    .replaceAll('׳', '') // ׳ Hebrew punctuation geresh
    .replaceAll('״', '') // ״ Hebrew punctuation gershayim
    .replaceAll("'", '') // ASCII apostrophe
    .replaceAll('"', ''); // ASCII quote

String normalizeHebrewFinals(String s) => stripGeresh(s)
    .replaceAll('ך', 'כ')
    .replaceAll('ם', 'מ')
    .replaceAll('ן', 'נ')
    .replaceAll('ף', 'פ')
    .replaceAll('ץ', 'צ')
    .replaceAll(' ', '');

// Full Hebrew keyboard — all 22 base letters, the 5 final forms (ך ם ן ף ץ),
// and a geresh key ('). It mirrors the letters-game keyboard so every game
// shows the same familiar layout, and the player types the exact letter form
// they want (final forms and geresh included).
const List<List<String>> _keyboardRows = [
  ['פ', 'ם', 'ן', 'ו', 'ט', 'א', 'ר', 'ק'],
  ['ף', 'ך', 'ל', 'ח', 'י', 'ע', 'כ', 'ג', 'ד', 'ש'],
  ['ץ', 'ת', 'צ', 'מ', 'נ', 'ה', 'ב', 'ס', 'ז', kGeresh],
];

class LetterBankInput extends StatefulWidget {
  final String answer;
  final bool enabled;
  final Future<bool> Function(String filled) onComplete;

  // Bought-letter reveal: the first [revealedLetterCount] slots are pre-filled
  // with the correct answer letters and locked (always capped so at least one
  // slot is left for the player). The buy button + coin cost are owned by the
  // parent; [onBuyLetter] is null when buying isn't possible (maxed / can't
  // afford). [showBuyLetter] controls whether the button is shown at all.
  final int revealedLetterCount;
  final VoidCallback? onBuyLetter;
  final int nextLetterPrice;
  final bool showBuyLetter;

  // Slot cap. 12 keeps the bank compact for the short image-game answers;
  // the proverbs game raises it so a whole proverb fits (words wrap to rows).
  final int maxLetters;

  const LetterBankInput({
    super.key,
    required this.answer,
    required this.enabled,
    required this.onComplete,
    this.revealedLetterCount = 0,
    this.onBuyLetter,
    this.nextLetterPrice = 0,
    this.showBuyLetter = false,
    this.maxLetters = 12,
  });

  @override
  State<LetterBankInput> createState() => _LetterBankInputState();
}

class _LetterBankInputState extends State<LetterBankInput> {
  static const Color _goldLight = Color(0xFFFFE082);

  late List<int> _wordLengths;
  late List<String?> _filled;
  late List<String> _answerLetters; // correct letter per slot, in slot order
  int _revealedCount = 0; // effective number of locked, pre-revealed slots
  bool _isSubmitting = false;
  bool _showError = false;

  bool get _isComplete => _filled.every((v) => v != null);
  // Clearable only if the player has placed a letter in a NON-revealed slot.
  bool get _canClear =>
      widget.enabled &&
      !_isSubmitting &&
      _filled.asMap().entries.any((e) => e.key >= _revealedCount && e.value != null);

  @override
  void initState() {
    super.initState();
    _resetForAnswer();
    _applyRevealedLetters();
  }

  @override
  void didUpdateWidget(covariant LetterBankInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer) {
      _resetForAnswer();
      _applyRevealedLetters();
    } else if (oldWidget.revealedLetterCount != widget.revealedLetterCount) {
      // A letter was just bought — pre-fill one more correct slot.
      _applyRevealedLetters();
    }
  }

  /// Locks the first N slots to the correct answer letters. Always leaves at
  /// least one slot for the player (never fully reveals the word).
  void _applyRevealedLetters() {
    final int n =
        widget.revealedLetterCount.clamp(0, math.max(0, _filled.length - 1)).toInt();
    for (var i = 0; i < n && i < _filled.length && i < _answerLetters.length; i++) {
      _filled[i] = _answerLetters[i];
    }
    _revealedCount = n;
  }

  void _resetForAnswer() {
    final words = canonicalizeGeresh(widget.answer).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var total = 0;
    final lengths = <int>[];
    final letters = <String>[];
    final cap = math.max(1, widget.maxLetters);
    for (final word in words) {
      if (total >= cap) break;
      final allowed = math.min(word.characters.length, cap - total);
      if (allowed > 0) {
        lengths.add(allowed);
        letters.addAll(word.characters.take(allowed));
        total += allowed;
      }
    }
    _wordLengths = lengths.isEmpty ? [1] : lengths;
    _answerLetters = letters;
    _filled = List<String?>.filled(math.max(1, total), null);
    _revealedCount = 0;
    _isSubmitting = false;
    _showError = false;
  }

  void _tapLetter(String letter) {
    if (!widget.enabled || _isSubmitting) return;
    final idx = _filled.indexOf(null);
    if (idx < 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _filled[idx] = letter;
      _showError = false;
    });
  }

  void _deleteOne() {
    if (!_canClear) return;
    HapticFeedback.lightImpact();
    setState(() {
      for (var i = _filled.length - 1; i >= _revealedCount; i--) {
        if (_filled[i] != null) {
          _filled[i] = null;
          break;
        }
      }
      _showError = false;
    });
  }

  Future<void> _submit() async {
    if (!widget.enabled || _isSubmitting || !_isComplete) return;
    HapticFeedback.heavyImpact();
    setState(() => _isSubmitting = true);
    var ok = false;
    try {
      ok = await widget.onComplete(_filled.join());
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _showError = !ok;
      if (!ok) {
        // Clear the player's letters but keep the ones they paid to reveal.
        _filled = List<String?>.filled(_filled.length, null);
        _applyRevealedLetters();
      }
    });
    if (!ok) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_isSubmitting;
    // Scrolls only if the bank (now with the optional buy-letter button) is
    // taller than the available space, so it never overflows on small screens.
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnswerSlots(filled: _filled, wordLengths: _wordLengths),
        SizedBox(
          height: 22,
          child: AnimatedOpacity(
            opacity: _showError ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: const Center(
              child: Text(
                'לא נכון, התור עובר',
                style: TextStyle(color: _goldLight, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _HebrewKeyboard(enabled: enabled, onLetter: _tapLetter),
        const SizedBox(height: 8),
        if (widget.showBuyLetter) ...[
          _BuyLetterAction(
            price: widget.nextLetterPrice,
            enabled: enabled && widget.onBuyLetter != null,
            onTap: widget.onBuyLetter,
          ),
          const SizedBox(height: 8),
        ],
        _ClearAction(enabled: _canClear, onTap: _deleteOne),
        const SizedBox(height: 8),
        _SubmitAction(enabled: enabled && _isComplete, isSubmitting: _isSubmitting, onTap: _submit),
        ],
      ),
    );
  }
}

class _AnswerSlots extends StatelessWidget {
  final List<String?> filled;
  final List<int> wordLengths;

  const _AnswerSlots({required this.filled, required this.wordLengths});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        const slotGap = 6.0;
        const wordGap = 16.0;
        final totalLetters = math.max(1, wordLengths.fold(0, (a, b) => a + b));
        final wordCount = math.max(1, wordLengths.length);
        final totalGapWidth = slotGap * (totalLetters - wordCount) + wordGap * (wordCount - 1);
        final slotSize = math.min(50.0, math.max(28.0, (constraints.maxWidth - 8 - totalGapWidth) / totalLetters));
        var idx = 0;
        final words = <Widget>[];
        for (final len in wordLengths) {
          final slots = <Widget>[];
          for (var i = 0; i < len; i++) {
            if (i > 0) slots.add(const SizedBox(width: slotGap));
            final shown = idx < filled.length ? filled[idx] : null;
            slots.add(_Slot(letter: shown, size: slotSize));
            idx++;
          }
          words.add(Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: slots));
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(textDirection: TextDirection.rtl, alignment: WrapAlignment.center, spacing: wordGap, runSpacing: 8, children: words),
        );
      });
}

class _Slot extends StatelessWidget {
  final String? letter;
  final double size;

  const _Slot({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    final filled = letter != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: filled
            ? const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFD4AF37), Color(0xFFA1811A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        color: filled ? null : const Color(0xFF07101F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: filled ? const Color(0xFFFFE082) : const Color(0xFFD4AF37).withOpacity(0.65), width: filled ? 2.2 : 1.5),
        boxShadow: filled
            ? [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.42), blurRadius: 12, offset: const Offset(0, 5))]
            : [BoxShadow(color: const Color(0xFF87CEEB).withOpacity(0.12), blurRadius: 8)],
      ),
      child: Text(letter ?? '', style: TextStyle(color: const Color(0xFF07101F), fontSize: math.max(16, size * 0.58), fontWeight: FontWeight.w900, height: 1)),
    );
  }
}

class _HebrewKeyboard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onLetter;

  const _HebrewKeyboard({required this.enabled, required this.onLetter});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        const gap = 4.0;
        const maxKeysInRow = 10;
        final keySize = math.min(44.0, math.max(24.0, (constraints.maxWidth - gap * (maxKeysInRow - 1)) / maxKeysInRow));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _keyboardRows.length; i++) ...[
              _KeyboardRow(letters: _keyboardRows[i], enabled: enabled, keySize: keySize, onLetter: onLetter),
              if (i != _keyboardRows.length - 1) const SizedBox(height: 7),
            ],
          ],
        );
      });
}

class _KeyboardRow extends StatelessWidget {
  final List<String> letters;
  final bool enabled;
  final double keySize;
  final ValueChanged<String> onLetter;

  const _KeyboardRow({required this.letters, required this.enabled, required this.keySize, required this.onLetter});

  @override
  Widget build(BuildContext context) => Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(letters.length, (i) {
          return Padding(
            padding: EdgeInsets.only(left: i == letters.length - 1 ? 0 : 4),
            child: _LetterKey(label: letters[i], size: keySize, enabled: enabled, onTap: () => onLetter(letters[i])),
          );
        }),
      );
}

class _LetterKey extends StatelessWidget {
  final String label;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  const _LetterKey({required this.label, required this.size, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: size,
            height: size + 10,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.white.withOpacity(0.58),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.45), width: 1.2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 5, offset: const Offset(0, 3)),
                BoxShadow(color: const Color(0xFF87CEEB).withOpacity(0.12), blurRadius: 8),
              ],
            ),
            child: Center(
              child: Text(label, style: TextStyle(color: enabled ? const Color(0xFF07101F) : Colors.grey.shade500, fontSize: math.max(20, size * 0.60), fontWeight: FontWeight.w900, height: 1)),
            ),
          ),
        ),
      );
}

class _ClearAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ClearAction({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: enabled ? onTap : null,
          icon: const Icon(Icons.backspace_rounded, size: 20),
          label: const Text('מחק', maxLines: 1, overflow: TextOverflow.visible),
          style: OutlinedButton.styleFrom(
            foregroundColor: enabled ? const Color(0xFFFFE082) : Colors.white38,
            disabledForegroundColor: Colors.white38,
            side: BorderSide(color: enabled ? const Color(0xFFD4AF37).withOpacity(0.85) : Colors.white.withOpacity(0.16), width: 1.4),
            backgroundColor: const Color(0xFF07101F).withOpacity(0.52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

class _BuyLetterAction extends StatelessWidget {
  final int price;
  final bool enabled;
  final VoidCallback? onTap;

  const _BuyLetterAction({required this.price, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF87CEEB);
    return SizedBox(
      width: 220,
      height: 44,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: enabled ? cyan : Colors.white38,
          disabledForegroundColor: Colors.white38,
          side: BorderSide(
            color: enabled ? cyan.withOpacity(0.8) : Colors.white.withOpacity(0.16),
            width: 1.4,
          ),
          backgroundColor: const Color(0xFF07101F).withOpacity(0.52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 18),
              const SizedBox(width: 6),
              const Text('קנה אות', textDirection: TextDirection.rtl),
              const SizedBox(width: 8),
              Text('$price', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 3),
              CoinIcon(size: 15, color: enabled ? const Color(0xFFFFC107) : Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitAction extends StatelessWidget {
  final bool enabled;
  final bool isSubmitting;
  final VoidCallback onTap;

  const _SubmitAction({required this.enabled, required this.isSubmitting, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            disabledBackgroundColor: const Color(0xFF07101F).withOpacity(0.72),
            foregroundColor: const Color(0xFF07101F),
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: enabled ? const Color(0xFFFFE082) : Colors.white.withOpacity(0.14), width: 1.2),
            ),
            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          child: isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF07101F)))
              : const Text('שלח ניחוש'),
        ),
      );
}
