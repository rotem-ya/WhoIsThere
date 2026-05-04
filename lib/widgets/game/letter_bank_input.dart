import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

String normalizeHebrewFinals(String s) {
  return s
      .replaceAll('ך', 'כ')
      .replaceAll('ם', 'מ')
      .replaceAll('ן', 'נ')
      .replaceAll('ף', 'פ')
      .replaceAll('ץ', 'צ')
      .replaceAll(' ', '');
}

const String _backspaceKey = '⌫';
const double _keyboardHorizontalPadding = 10.0;
const double _keyboardGap = 5.0;
const double _keyboardRowGap = 10.0;
const double _keyboardMinKeySize = 31.0;
const double _keyboardMaxKeySize = 54.0;
const int _keyboardMaxKeysInRow = 10;

// Visual RTL order: index 0 is the rightmost key on screen.
const List<List<String>> _keyboardRows = [
  ['פ', 'ם', 'ן', 'ו', 'ט', 'א', 'ר', 'ק'],
  ['ף', 'ך', 'ל', 'ח', 'י', 'ע', 'כ', 'ג', 'ד', 'ש'],
  [_backspaceKey, 'ץ', 'ת', 'צ', 'מ', 'נ', 'ה', 'ב', 'ס', 'ז'],
];

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
  late List<int> _wordLengths;
  late List<String?> _filled;
  bool _isSubmitting = false;
  bool _submitLocked = false;
  bool _showError = false;
  bool _hasUsedUndo = false;
  String? _previewLetter;
  int _previewToken = 0;

  bool get _isComplete => _filled.every((v) => v != null);

  @override
  void initState() {
    super.initState();
    _resetForAnswer();
  }

  @override
  void didUpdateWidget(covariant LetterBankInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer) _resetForAnswer();
  }

  void _resetForAnswer() {
    final rawWords = widget.answer
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    var total = 0;
    final lengths = <int>[];
    for (final word in rawWords) {
      if (total >= 12) break;
      final lettersInWord = word.characters.length;
      final allowed = math.min(lettersInWord, 12 - total);
      if (allowed > 0) {
        lengths.add(allowed);
        total += allowed;
      }
    }

    _wordLengths = lengths.isEmpty ? [1] : lengths;
    _filled = List<String?>.filled(math.max(1, total), null);
    _isSubmitting = false;
    _submitLocked = false;
    _showError = false;
    _hasUsedUndo = false;
    _previewLetter = null;
    _previewToken = 0;
  }

  void _showLetterPreview(String letter) {
    _previewToken++;
    final token = _previewToken;
    setState(() => _previewLetter = letter);
    Future.delayed(const Duration(milliseconds: 230), () {
      if (!mounted || token != _previewToken) return;
      setState(() => _previewLetter = null);
    });
  }

  Future<void> _tapLetter(String letter) async {
    if (!widget.enabled || _submitLocked) return;
    final idx = _filled.indexOf(null);
    if (idx < 0) return;

    HapticFeedback.lightImpact();
    setState(() {
      _filled[idx] = letter;
      _showError = false;
      _hasUsedUndo = false;
    });
    _showLetterPreview(letter);
  }

  void _undoLastLetter() {
    if (!widget.enabled || _submitLocked || _hasUsedUndo) return;
    for (var i = _filled.length - 1; i >= 0; i--) {
      if (_filled[i] != null) {
        HapticFeedback.mediumImpact();
        setState(() {
          _filled[i] = null;
          _hasUsedUndo = true;
          _showError = false;
        });
        return;
      }
    }
  }

  Future<void> _submit() async {
    if (!widget.enabled || _submitLocked || !_isComplete) return;

    _submitLocked = true;
    HapticFeedback.heavyImpact();
    setState(() => _isSubmitting = true);
    bool ok = false;
    try {
      ok = await widget.onComplete(_filled.join());
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _showError = !ok;
      if (!ok) _submitLocked = false;
    });

    if (!ok) {
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showError = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_submitLocked;
    final canUndo = enabled && !_hasUsedUndo && _filled.any((v) => v != null);
    final canSubmit = enabled && _isComplete;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnswerSlots(
                        filled: _filled,
                        wordLengths: _wordLengths,
                      ),
                      SizedBox(
                        height: 20,
                        child: AnimatedOpacity(
                          opacity: _showError ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: const Center(
                            child: Text(
                              'לא נכון, התור עובר',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _HebrewKeyboard(
                        enabled: enabled,
                        canUndo: canUndo,
                        onLetter: _tapLetter,
                        onUndo: _undoLastLetter,
                      ),
                      _GuessControls(
                        canSubmit: canSubmit,
                        isSubmitting: _isSubmitting,
                        onSubmit: _submit,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(child: _LetterPreview(letter: _previewLetter)),
          ],
        );
      },
    );
  }
}

class _AnswerSlots extends StatelessWidget {
  final List<String?> filled;
  final List<int> wordLengths;

  const _AnswerSlots({required this.filled, required this.wordLengths});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const slotGap = 6.0;
        const wordGap = 14.0;

        final totalLetters = math.max(1, wordLengths.fold(0, (a, b) => a + b));
        final wordCount = math.max(1, wordLengths.length);
        final usableWidth = constraints.maxWidth - 8.0;
        final totalGapWidth =
            slotGap * (totalLetters - wordCount) + wordGap * (wordCount - 1);
        final slotSize = math.min(
          52.0,
          math.max(30.0, (usableWidth - totalGapWidth) / totalLetters),
        );

        var idx = 0;
        final wordWidgets = <Widget>[];
        for (final wordLen in wordLengths) {
          final slots = <Widget>[];
          for (var i = 0; i < wordLen; i++) {
            if (i > 0) slots.add(const SizedBox(width: slotGap));
            final letter = idx < filled.length ? filled[idx] : null;
            slots.add(_Slot(letter: letter, size: slotSize));
            idx++;
          }
          wordWidgets.add(Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: slots,
          ));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            spacing: wordGap,
            runSpacing: 9,
            children: wordWidgets,
          ),
        );
      },
    );
  }
}

class _Slot extends StatelessWidget {
  final String? letter;
  final double size;

  const _Slot({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    final isFilled = letter != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFFEAF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isFilled ? const Color(0xFF58B8E8) : const Color(0xFFB8D7EA),
          width: isFilled ? 2.4 : 1.5,
        ),
        boxShadow: isFilled
            ? [
                BoxShadow(
                  color: const Color(0xFF58B8E8).withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          letter ?? '',
          style: TextStyle(
            color: AppColors.darkBlue,
            fontSize: size * 0.66,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _HebrewKeyboard extends StatelessWidget {
  final bool enabled;
  final bool canUndo;
  final ValueChanged<String> onLetter;
  final VoidCallback onUndo;

  const _HebrewKeyboard({
    required this.enabled,
    required this.canUndo,
    required this.onLetter,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = MediaQuery.sizeOf(context).width - 48;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - _keyboardHorizontalPadding * 2
            : fallbackWidth;
        final widthKeySize =
            (availableWidth - _keyboardGap * (_keyboardMaxKeysInRow - 1)) /
                _keyboardMaxKeysInRow;
        final keySize = math.min(
          _keyboardMaxKeySize,
          math.max(_keyboardMinKeySize, widthKeySize),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _keyboardHorizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _keyboardRows.length; i++) ...[
                _KeyboardRow(
                  letters: _keyboardRows[i],
                  enabled: enabled,
                  canUndo: canUndo,
                  keySize: keySize,
                  gap: _keyboardGap,
                  onLetter: onLetter,
                  onUndo: onUndo,
                ),
                if (i != _keyboardRows.length - 1)
                  const SizedBox(height: _keyboardRowGap),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  final List<String> letters;
  final bool enabled;
  final bool canUndo;
  final double keySize;
  final double gap;
  final ValueChanged<String> onLetter;
  final VoidCallback onUndo;

  const _KeyboardRow({
    required this.letters,
    required this.enabled,
    required this.canUndo,
    required this.keySize,
    required this.gap,
    required this.onLetter,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(letters.length, (i) {
          final label = letters[i];
          final isBackspace = label == _backspaceKey;
          final isEnabled = isBackspace ? canUndo : enabled;
          return Padding(
            padding: EdgeInsets.only(left: i == letters.length - 1 ? 0 : gap),
            child: _LetterKey(
              label: label,
              size: keySize,
              enabled: isEnabled,
              isBackspace: isBackspace,
              onTap: isBackspace ? onUndo : () => onLetter(label),
            ),
          );
        }),
      ),
    );
  }
}

class _LetterKey extends StatefulWidget {
  final String label;
  final double size;
  final bool enabled;
  final bool isBackspace;
  final VoidCallback onTap;

  const _LetterKey({
    required this.label,
    required this.size,
    required this.enabled,
    required this.isBackspace,
    required this.onTap,
  });

  @override
  State<_LetterKey> createState() => _LetterKeyState();
}

class _LetterKeyState extends State<_LetterKey> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final keyColor = widget.enabled ? Colors.white : const Color(0xFFE8EEF4);
    final borderColor = widget.enabled ? const Color(0xFFA9D8F0) : const Color(0xFFCAD2DA);
    final textColor = widget.enabled ? AppColors.darkBlue : const Color(0xFF88929D);
    final keyHeight = widget.size * 1.18;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTapUp: widget.enabled
          ? (_) {
              _setPressed(false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 1.07 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: keyHeight,
          decoration: BoxDecoration(
            color: keyColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF58B8E8).withOpacity(_pressed ? 0.24 : 0.12),
                blurRadius: _pressed ? 10 : 5,
                offset: Offset(0, _pressed ? 4 : 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isBackspace
              ? Icon(
                  Icons.backspace_outlined,
                  size: widget.size * 0.50,
                  color: textColor,
                )
              : SizedBox(
                  width: widget.size * 0.72,
                  height: keyHeight * 0.78,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _GuessControls extends StatelessWidget {
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _GuessControls({
    required this.canSubmit,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: canSubmit ? onSubmit : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: Colors.white.withOpacity(0.14),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('שלח ניחוש'),
      ),
    );
  }
}

class _LetterPreview extends StatelessWidget {
  final String? letter;

  const _LetterPreview({required this.letter});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 90),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: letter == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Container(
              key: ValueKey(letter),
              width: 78,
              height: 78,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF58B8E8), width: 2.6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF58B8E8).withOpacity(0.34),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                letter!,
                style: const TextStyle(
                  color: AppColors.darkBlue,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
    );
  }
}
