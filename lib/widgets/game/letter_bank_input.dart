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
  'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט', 'י', 'כ',
  'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ', 'ק', 'ר', 'ש', 'ת',
];

/// Letter-bank answer input for "Guess the Place".
/// Local UI state only — never persists partial input.
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
  void didUpdateWidget(covariant LetterBankInput old) {
    super.didUpdateWidget(old);
    if (old.answer != widget.answer) {
      _initSlots();
    }
  }

  void _initSlots() {
    _answerChars = widget.answer.runes.map(String.fromCharCode).toList();
    final letterCount = _answerChars.where((c) => c != ' ').length;
    _filled = List<String?>.filled(letterCount, null);
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
    int lastIdx = -1;
    for (int i = _filled.length - 1; i >= 0; i--) {
      if (_filled[i] != null) {
        lastIdx = i;
        break;
      }
    }
    if (lastIdx == -1) return;
    setState(() {
      _filled[lastIdx] = null;
      _showError = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    // Rebuild candidate string preserving spaces in original positions
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
      // Parent navigates on success — keep boxes filled.
    } else {
      setState(() {
        _isSubmitting = false;
        _showError = true;
      });
      _resetFilled();
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _showError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnswerBoard(
          answerChars: _answerChars,
          filled: _filled,
          enabled: widget.enabled && !_isSubmitting,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Center(
            child: AnimatedOpacity(
              opacity: _showError ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Text(
                'תשובה שגויה — נסה שוב',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _LetterBank(
          enabled: widget.enabled && !_isSubmitting,
          onTap: _onTapLetter,
          onBackspace: _onBackspace,
        ),
      ],
    );
  }
}

class _AnswerBoard extends StatelessWidget {
  final List<String> answerChars;
  final List<String?> filled;
  final bool enabled;

  const _AnswerBoard({
    required this.answerChars,
    required this.filled,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    // Group chars into words, render each word as a non-breaking Row,
    // then wrap words in a Wrap so multi-word answers wrap at word boundaries.
    final words = <List<int>>[]; // list of letter-index lists per word
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.center,
        spacing: 14, // gap between words
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
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

class _LetterSlot extends StatelessWidget {
  final String? letter;
  final bool enabled;

  const _LetterSlot({required this.letter, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final filled = letter != null;
    return Container(
      width: 34,
      height: 40,
      decoration: BoxDecoration(
        color: filled
            ? AppColors.primary.withOpacity(0.10)
            : enabled
                ? Colors.white
                : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: filled
              ? AppColors.primary
              : enabled
                  ? AppColors.primary.withOpacity(0.35)
                  : Colors.grey.shade300,
          width: filled ? 1.8 : 1.4,
        ),
      ),
      child: Center(
        child: Text(
          letter ?? '',
          style: const TextStyle(
            color: AppColors.darkBlue,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _LetterBank extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onTap;
  final VoidCallback onBackspace;

  const _LetterBank({
    required this.enabled,
    required this.onTap,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Prefer two rows, then fall back to three rows before shrinking keys.
        const twoRowLetters = 11;
        const threeRowLetters = 8;
        const spacing = 6.0;
        const preferredMinButtonSize = 26.0;
        const minShrinkButtonSize = 20.0;
        const maxButtonSize = 38.0;
        const horizontalPadding = 8.0;
        double buttonSizeFor(int lettersPerRow) {
          final available = constraints.maxWidth -
              horizontalPadding -
              (spacing * (lettersPerRow - 1));
          return available / lettersPerRow;
        }

        final twoRowButtonSize = buttonSizeFor(twoRowLetters);
        final lettersPerRow = twoRowButtonSize >= preferredMinButtonSize
            ? twoRowLetters
            : threeRowLetters;
        final rawButtonSize = buttonSizeFor(lettersPerRow);
        final btnW = rawButtonSize.clamp(minShrinkButtonSize, maxButtonSize);
        final btnH = btnW + 6;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                textDirection: TextDirection.rtl,
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.center,
                children: _hebrewAlphabet.map((letter) {
                  return _BankKey(
                    label: letter,
                    width: btnW,
                    height: btnH,
                    enabled: enabled,
                    onTap: () => onTap(letter),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Center(
                  child: _BackspaceKey(
                    enabled: enabled,
                    onTap: onBackspace,
                    height: btnH,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BankKey extends StatelessWidget {
  final String label;
  final double width;
  final double height;
  final bool enabled;
  final VoidCallback onTap;

  const _BankKey({
    required this.label,
    required this.width,
    required this.height,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled
                  ? AppColors.primary.withOpacity(0.55)
                  : Colors.grey.shade300,
              width: 1.4,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.darkBlue : Colors.grey.shade500,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final double height;

  const _BackspaceKey({
    required this.enabled,
    required this.onTap,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.secondary.withOpacity(0.10)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? AppColors.secondary.withOpacity(0.55)
                  : Colors.grey.shade300,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.backspace_outlined,
                size: 18,
                color: enabled ? AppColors.secondary : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                'מחק',
                style: TextStyle(
                  color: enabled ? AppColors.secondary : Colors.grey.shade500,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
