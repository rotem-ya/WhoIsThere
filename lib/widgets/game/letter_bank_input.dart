import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Single source of truth for Hebrew normalization in answer comparison.
/// Maps final letters to their non-final form and strips spaces.
String normalizeHebrewFinals(String s) {
  return s
      .replaceAll('ך', 'כ')
      .replaceAll('ם', 'מ')
      .replaceAll('ן', 'נ')
      .replaceAll('ף', 'פ')
      .replaceAll('ץ', 'צ')
      .replaceAll(' ', '');
}

/// Hebrew alphabet without final letters, ordered א → ת.
const List<String> _hebrewAlphabet = [
  'א',
  'ב',
  'ג',
  'ד',
  'ה',
  'ו',
  'ז',
  'ח',
  'ט',
  'י',
  'כ',
  'ל',
  'מ',
  'נ',
  'ס',
  'ע',
  'פ',
  'צ',
  'ק',
  'ר',
  'ש',
  'ת',
];

/// Compact responsive answer input for the game board.
/// The widget is intentionally height-aware, so it never causes screen overflow.
class LetterBankInput extends StatefulWidget {
  final String answer;
  final bool enabled;
  final Future<bool> Function(String filled) onComplete;

  const LetterBankInput({
    super.key,
    required this.answer,
    required this.enabled,
    required this.onComplete,
  });

  @override
  State<LetterBankInput> createState() => _LetterBankInputState();
}

class _LetterBankInputState extends State<LetterBankInput> {
  late List<String?> _filled;
  late List<String> _answerChars;
  bool _isSubmitting = false;
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _initSlots();
  }

  @override
  void didUpdateWidget(covariant LetterBankInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer) {
      _initSlots();
    }
  }

  void _initSlots() {
    _answerChars = widget.answer.runes.map(String.fromCharCode).toList();
    final letterCount = _answerChars.where((c) => c != ' ').length;
    _filled = List<String?>.filled(letterCount, null);
    _showError = false;
    _isSubmitting = false;
  }

  void _resetFilled() {
    setState(() {
      _filled = List<String?>.filled(_filled.length, null);
    });
  }

  Future<void> _onTapLetter(String letter) async {
    if (!widget.enabled || _isSubmitting) return;
    final emptyIdx = _filled.indexOf(null);
    if (emptyIdx == -1) return;

    setState(() {
      _filled[emptyIdx] = letter;
      _showError = false;
    });

    if (_filled.every((s) => s != null)) {
      await _submit();
    }
  }

  void _onBackspace() {
    if (!widget.enabled || _isSubmitting) return;
    for (int i = _filled.length - 1; i >= 0; i--) {
      if (_filled[i] != null) {
        setState(() {
          _filled[i] = null;
          _showError = false;
        });
        return;
      }
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final buf = StringBuffer();
    int letterIdx = 0;
    for (final c in _answerChars) {
      if (c == ' ') {
        buf.write(' ');
      } else {
        buf.write(_filled[letterIdx++] ?? '');
      }
    }

    bool ok = false;
    try {
      ok = await widget.onComplete(buf.toString());
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    if (ok) {
      setState(() => _isSubmitting = false);
    } else {
      setState(() {
        _isSubmitting = false;
        _showError = true;
      });
      _resetFilled();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _showError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = math.max(120.0, constraints.maxHeight);
        final answerHeight = _filled.length > 8 ? 96.0 : 56.0;
        const errorHeight = 22.0;
        final keyboardHeight =
            math.max(80.0, maxHeight - answerHeight - errorHeight);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: answerHeight,
              child: _AnswerBoard(
                answerChars: _answerChars,
                filled: _filled,
                enabled: widget.enabled && !_isSubmitting,
                onBackspace: _onBackspace,
              ),
            ),
            SizedBox(
              height: errorHeight,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showError ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Text(
                    'לא נכון, נסה שוב',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: keyboardHeight,
              child: _LetterKeyboard(
                enabled: widget.enabled && !_isSubmitting,
                onTap: _onTapLetter,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnswerBoard extends StatelessWidget {
  final List<String> answerChars;
  final List<String?> filled;
  final bool enabled;
  final VoidCallback onBackspace;

  const _AnswerBoard({
    required this.answerChars,
    required this.filled,
    required this.enabled,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final words = <List<int>>[];
    final currentWord = <int>[];
    int letterIdx = 0;

    for (final c in answerChars) {
      if (c == ' ') {
        if (currentWord.isNotEmpty) {
          words.add(List.of(currentWord));
          currentWord.clear();
        }
      } else {
        currentWord.add(letterIdx++);
      }
    }
    if (currentWord.isNotEmpty) words.add(currentWord);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Width available after the delete button (46 px) and its gap (6 px).
        final contentWidth = constraints.maxWidth - 52.0;
        final maxLettersInWord = words.isEmpty
            ? 1
            : words.map((w) => w.length).reduce(math.max);

        // Slot width scales down with long words so they never overflow the row.
        final slotWidth =
            (contentWidth / maxLettersInWord).clamp(18.0, 42.0).toDouble();
        final slotHeight = (slotWidth + 6).clamp(30.0, 48.0).toDouble();
        // Font scales with slot so small slots stay legible.
        final slotFontSize = (slotWidth * 0.55).clamp(11.0, 20.0).toDouble();

        return Row(
          children: [
            Expanded(
              child: Center(
                child: Wrap(
                  textDirection: TextDirection.rtl,
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: words.map((wordIndices) {
                    return Row(
                      textDirection: TextDirection.rtl,
                      mainAxisSize: MainAxisSize.min,
                      children: wordIndices.map((idx) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _LetterSlot(
                            letter: filled[idx],
                            enabled: enabled,
                            width: slotWidth,
                            height: slotHeight,
                            fontSize: slotFontSize,
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _DeleteButton(enabled: enabled, onTap: onBackspace),
          ],
        );
      },
    );
  }
}

class _LetterSlot extends StatelessWidget {
  final String? letter;
  final bool enabled;
  final double width;
  final double height;
  final double fontSize;

  const _LetterSlot({
    required this.letter,
    required this.enabled,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = letter != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFFEDEBFF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFilled
              ? AppColors.primary
              : enabled
                  ? const Color(0xFFD7D4FF)
                  : Colors.grey.shade300,
          width: isFilled ? 2.2 : 1.5,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          letter ?? '',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _DeleteButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFFFEEF2) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled
                  ? AppColors.secondary.withOpacity(0.35)
                  : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.backspace_outlined,
            color: enabled ? AppColors.secondary : Colors.grey.shade500,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _LetterKeyboard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onTap;

  const _LetterKeyboard({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        // More columns on wider screens; fewer on narrow to keep keys tappable.
        final columns = width < 260 ? 5 : width < 340 ? 6 : 7;
        final rows = (_hebrewAlphabet.length / columns).ceil();
        const gap = 7.0;

        final keyWidth = (width - gap * (columns - 1)) / columns;
        final keyHeight = (height - gap * (rows - 1)) / rows;

        // Minimum 24 px so keys are always visible; no hard overflow from clamp.
        final keySize = math.min(keyWidth, keyHeight).clamp(24.0, 48.0);
        final fontSize = (keySize * 0.48).clamp(13.0, 24.0).toDouble();

        return Center(
          child: Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: _hebrewAlphabet.map((letter) {
              return _KeyboardKey(
                label: letter,
                size: keySize,
                fontSize: fontSize,
                enabled: enabled,
                onTap: () => onTap(letter),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _KeyboardKey extends StatelessWidget {
  final String label;
  final double size;
  final double fontSize;
  final bool enabled;
  final VoidCallback onTap;

  const _KeyboardKey({
    required this.label,
    required this.size,
    required this.fontSize,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color:
                  enabled ? const Color(0xFFC9C4FF) : Colors.grey.shade300,
              width: 1.6,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.darkBlue : Colors.grey.shade500,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
