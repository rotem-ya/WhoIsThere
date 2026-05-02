import 'dart:math' as math;

import 'package:flutter/material.dart';
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

const List<List<String>> _keyboardRows = [
  ['ק', 'ר', 'א', 'ט', 'ו', 'ן', 'ם', 'פ'],
  ['ש', 'ד', 'ג', 'כ', 'ע', 'י', 'ח', 'ל', 'ך', 'ף'],
  ['ז', 'ס', 'ב', 'ה', 'נ', 'מ', 'צ', 'ת', 'ץ'],
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
  late List<String?> _filled;
  bool _isSubmitting = false;
  bool _showError = false;

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
    final count = widget.answer.replaceAll(' ', '').characters.take(12).length;
    _filled = List<String?>.filled(count, null);
    _isSubmitting = false;
    _showError = false;
  }

  void _clear() {
    setState(() => _filled = List<String?>.filled(_filled.length, null));
  }

  Future<void> _tapLetter(String letter) async {
    if (!widget.enabled || _isSubmitting) return;
    final idx = _filled.indexOf(null);
    if (idx < 0) return;

    setState(() {
      _filled[idx] = letter;
      _showError = false;
    });

    if (_filled.every((v) => v != null)) await _submit();
  }

  void _backspace() {
    if (!widget.enabled || _isSubmitting) return;
    for (var i = _filled.length - 1; i >= 0; i--) {
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
    bool ok = false;
    try {
      ok = await widget.onComplete(_filled.join());
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    if (ok) {
      setState(() => _isSubmitting = false);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _showError = true;
    });
    _clear();

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showError = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_isSubmitting;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnswerSlots(
                  filled: _filled,
                  enabled: enabled,
                  onBackspace: _backspace,
                ),
                SizedBox(
                  height: 22,
                  child: AnimatedOpacity(
                    opacity: _showError ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Center(
                      child: Text(
                        'לא נכון, נסה שוב',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _HebrewKeyboard(
                  enabled: enabled,
                  onLetter: _tapLetter,
                  onBackspace: _backspace,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnswerSlots extends StatelessWidget {
  final List<String?> filled;
  final bool enabled;
  final VoidCallback onBackspace;

  const _AnswerSlots({
    required this.filled,
    required this.enabled,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        final count = math.max(1, math.min(12, filled.length));
        final usableWidth = math.max(220.0, constraints.maxWidth - 8.0);
        final size = math.min(
          34.0,
          math.max(24.0, (usableWidth - gap * (count - 1)) / count),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(
            textDirection: TextDirection.rtl,
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: 6,
            children: List.generate(count, (i) {
              return _Slot(letter: filled[i], size: size);
            }),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isFilled ? const Color(0xFFEDEBFF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFilled ? AppColors.primary : const Color(0xFFD7D4FF),
          width: isFilled ? 2 : 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter ?? '',
        style: TextStyle(
          color: AppColors.darkBlue,
          fontSize: math.max(14, size * 0.55),
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _HebrewKeyboard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;

  const _HebrewKeyboard({
    required this.enabled,
    required this.onLetter,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        const maxKeysInRow = 10;
        final keySize = math.min(
          38.0,
          math.max(25.0, (constraints.maxWidth - gap * (maxKeysInRow - 1)) / maxKeysInRow),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _keyboardRows.length; i++) ...[
              _KeyboardRow(
                letters: _keyboardRows[i],
                enabled: enabled,
                keySize: keySize,
                onLetter: onLetter,
              ),
              if (i != _keyboardRows.length - 1) const SizedBox(height: 7),
            ],
            const SizedBox(height: 10),
            _BackAction(enabled: enabled, onTap: onBackspace),
          ],
        );
      },
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  final List<String> letters;
  final bool enabled;
  final double keySize;
  final ValueChanged<String> onLetter;

  const _KeyboardRow({
    required this.letters,
    required this.enabled,
    required this.keySize,
    required this.onLetter,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 4.0;
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i == letters.length - 1 ? 0 : gap),
          child: _LetterKey(
            label: letters[i],
            size: keySize,
            enabled: enabled,
            onTap: () => onLetter(letters[i]),
          ),
        );
      }),
    );
  }
}

class _LetterKey extends StatelessWidget {
  final String label;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  const _LetterKey({
    required this.label,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: size,
          height: size + 4,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC9C4FF), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.darkBlue : Colors.grey.shade500,
                fontSize: math.max(17, size * 0.58),
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

class _BackAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _BackAction({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: const Icon(Icons.backspace_outlined, size: 18),
        label: const Text('מחיקה'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
