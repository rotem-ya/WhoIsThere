import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

String normalizeHebrewFinals(String s) => s
    .replaceAll('ך', 'כ')
    .replaceAll('ם', 'מ')
    .replaceAll('ן', 'נ')
    .replaceAll('ף', 'פ')
    .replaceAll('ץ', 'צ')
    .replaceAll(' ', '');

const List<List<String>> _keyboardRows = [
  ['פ', 'ם', 'ן', 'ו', 'ט', 'א', 'ר', 'ק'],
  ['ף', 'ך', 'ל', 'ח', 'י', 'ע', 'כ', 'ג', 'ד', 'ש'],
  ['ץ', 'ת', 'צ', 'מ', 'נ', 'ה', 'ב', 'ס', 'ז'],
];

class LetterBankInput extends StatefulWidget {
  final String answer;
  final bool enabled;
  final Future<bool> Function(String filled) onComplete;

  const LetterBankInput({super.key, required this.answer, required this.enabled, required this.onComplete});

  @override
  State<LetterBankInput> createState() => _LetterBankInputState();
}

class _LetterBankInputState extends State<LetterBankInput> {
  late List<int> _wordLengths;
  late List<String?> _filled;
  bool _isSubmitting = false;
  bool _showError = false;
  bool _undoUsed = false;

  bool get _isComplete => _filled.every((v) => v != null);
  bool get _canUndo => widget.enabled && !_isSubmitting && !_undoUsed && _filled.any((v) => v != null);

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
    final words = widget.answer.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var total = 0;
    final lengths = <int>[];
    for (final word in words) {
      if (total >= 12) break;
      final allowed = math.min(word.characters.length, 12 - total);
      if (allowed > 0) {
        lengths.add(allowed);
        total += allowed;
      }
    }
    _wordLengths = lengths.isEmpty ? [1] : lengths;
    _filled = List<String?>.filled(math.max(1, total), null);
    _isSubmitting = false;
    _showError = false;
    _undoUsed = false;
  }

  void _tapLetter(String letter) {
    if (!widget.enabled || _isSubmitting) return;
    final idx = _filled.indexOf(null);
    if (idx < 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _filled[idx] = letter;
      _showError = false;
      _undoUsed = false;
    });
  }

  void _undoLastLetter() {
    if (!_canUndo) return;
    for (var i = _filled.length - 1; i >= 0; i--) {
      if (_filled[i] == null) continue;
      HapticFeedback.mediumImpact();
      setState(() {
        _filled[i] = null;
        _showError = false;
        _undoUsed = true;
      });
      return;
    }
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
        _filled = List<String?>.filled(_filled.length, null);
        _undoUsed = false;
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AnswerSlots(filled: _filled, wordLengths: _wordLengths),
              SizedBox(
                height: 22,
                child: AnimatedOpacity(
                  opacity: _showError ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Center(
                    child: Text('לא נכון, התור עובר', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _HebrewKeyboard(enabled: enabled, onLetter: _tapLetter),
              const SizedBox(height: 10),
              _UndoAction(enabled: _canUndo, onTap: _undoLastLetter),
              const SizedBox(height: 10),
              _SubmitAction(enabled: enabled && _isComplete, isSubmitting: _isSubmitting, onTap: _submit),
            ],
          ),
        ),
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
        const slotGap = 4.0;
        const wordGap = 12.0;
        final totalLetters = math.max(1, wordLengths.fold(0, (a, b) => a + b));
        final wordCount = math.max(1, wordLengths.length);
        final totalGapWidth = slotGap * (totalLetters - wordCount) + wordGap * (wordCount - 1);
        final slotSize = math.min(44.0, math.max(22.0, (constraints.maxWidth - 8 - totalGapWidth) / totalLetters));
        var idx = 0;
        final words = <Widget>[];
        for (final len in wordLengths) {
          final slots = <Widget>[];
          for (var i = 0; i < len; i++) {
            if (i > 0) slots.add(const SizedBox(width: slotGap));
            slots.add(_Slot(letter: idx < filled.length ? filled[idx] : null, size: slotSize));
            idx++;
          }
          words.add(Row(textDirection: TextDirection.rtl, mainAxisSize: MainAxisSize.min, children: slots));
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(textDirection: TextDirection.rtl, alignment: WrapAlignment.center, spacing: wordGap, runSpacing: 6, children: words),
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFEDEBFF) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: filled ? AppColors.primary : const Color(0xFFD7D4FF), width: filled ? 2 : 1.4),
      ),
      child: Text(letter ?? '', style: TextStyle(color: AppColors.darkBlue, fontSize: math.max(14, size * 0.55), fontWeight: FontWeight.w900, height: 1)),
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
        final keySize = math.min(44.0, math.max(22.0, (constraints.maxWidth - gap * (maxKeysInRow - 1)) / maxKeysInRow));
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
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: size,
            height: size + 10,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9C4FF), width: 1.2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Center(
              child: Text(label, style: TextStyle(color: enabled ? AppColors.darkBlue : Colors.grey.shade500, fontSize: math.max(20, size * 0.60), fontWeight: FontWeight.w900, height: 1)),
            ),
          ),
        ),
      );
}

class _UndoAction extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _UndoAction({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        height: 46,
        child: OutlinedButton.icon(
          onPressed: enabled ? onTap : null,
          icon: const Icon(Icons.undo_rounded, size: 20),
          label: const Text('בטל אות אחרונה'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
            side: BorderSide(color: Colors.white.withOpacity(enabled ? 0.38 : 0.16)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      );
}

class _SubmitAction extends StatelessWidget {
  final bool enabled;
  final bool isSubmitting;
  final VoidCallback onTap;

  const _SubmitAction({required this.enabled, required this.isSubmitting, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: Colors.white.withOpacity(0.14),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white38,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          child: isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('שלח ניחוש'),
        ),
      );
}
