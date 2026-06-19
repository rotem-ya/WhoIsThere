import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/game/letter_bank_input.dart';

class GuessModeOverlay extends StatefulWidget {
  final String guesserName;
  final bool isMyGuess;
  final int? deadlineMs;
  final String answer;
  final Future<bool> Function(String)? onSubmit;
  // Bought-letter reveal, threaded down to the letter bank.
  final int revealedLetterCount;
  final VoidCallback? onBuyLetter;
  final int nextLetterPrice;
  final bool showBuyLetter;

  const GuessModeOverlay({
    super.key,
    required this.guesserName,
    required this.isMyGuess,
    required this.deadlineMs,
    required this.answer,
    this.onSubmit,
    this.revealedLetterCount = 0,
    this.onBuyLetter,
    this.nextLetterPrice = 0,
    this.showBuyLetter = false,
  });

  @override
  State<GuessModeOverlay> createState() => _GuessModeOverlayState();
}

class _GuessModeOverlayState extends State<GuessModeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameColor = widget.isMyGuess
        ? const Color(0xFF00F2FF)
        : const Color(0xFFFF9F43);

    final displayName = widget.isMyGuess
        ? 'אתה'
        : (widget.guesserName.isEmpty ? 'יריב' : widget.guesserName);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF020912).withOpacity(0.97),
                const Color(0xFF04111E).withOpacity(0.97),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ── Glow ring + name ──────────────────────────────────────
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) {
                    final glow = _glowAnim.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: nameColor.withOpacity(0.25 + glow * 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: nameColor.withOpacity(0.12 + glow * 0.18),
                            blurRadius: 30 + glow * 20,
                            spreadRadius: 2,
                          ),
                        ],
                        color: nameColor.withOpacity(0.05 + glow * 0.05),
                      ),
                      child: child,
                    );
                  },
                  child: Column(
                    children: [
                      Text(
                        '🎯',
                        style: const TextStyle(fontSize: 36),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$displayName מנחש!',
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: nameColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          shadows: [
                            Shadow(color: nameColor.withOpacity(0.55), blurRadius: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Body ──────────────────────────────────────────────────
                Expanded(
                  child: widget.isMyGuess
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: LetterBankInput(
                            key: widget.deadlineMs != null
                                ? ValueKey('overlay-guess-${widget.deadlineMs}')
                                : null,
                            answer: widget.answer,
                            enabled: widget.onSubmit != null,
                            onComplete: widget.onSubmit ?? (_) async => false,
                            revealedLetterCount: widget.revealedLetterCount,
                            onBuyLetter: widget.onBuyLetter,
                            nextLetterPrice: widget.nextLetterPrice,
                            showBuyLetter: widget.showBuyLetter,
                          ),
                        )
                      : _SpectatorBody(answer: widget.answer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Spectator view ────────────────────────────────────────────────────────────

class _SpectatorBody extends StatefulWidget {
  final String answer;
  const _SpectatorBody({required this.answer});

  @override
  State<_SpectatorBody> createState() => _SpectatorBodyState();
}

class _SpectatorBodyState extends State<_SpectatorBody> {
  int _dotPhase = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => _dotPhase = (_dotPhase + 1) % 3);
    });
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(3, (i) {
      final lit = i <= _dotPhase;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit
              ? const Color(0xFFFF9F43)
              : const Color(0xFF87CEEB).withOpacity(0.20),
          boxShadow: lit
              ? [BoxShadow(color: const Color(0xFFFF9F43).withOpacity(0.55), blurRadius: 10)]
              : [],
        ),
      );
    });

    // Build word-length list from answer (mirror LetterBankInput logic)
    final words = stripGeresh(widget.answer).trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
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
    final wordLengths = lengths.isEmpty ? [1] : lengths;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Typing dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'מנחש',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFF87CEEB),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Row(children: dots),
          ],
        ),

        const SizedBox(height: 28),

        // Blank answer slots — show structure without revealing letters
        _BlankSlots(wordLengths: wordLengths),

        const SizedBox(height: 24),

        Text(
          '${wordLengths.length} מילה${wordLengths.length > 1 ? "ות" : ""}, $total אות${total > 1 ? "יות" : ""}',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white.withOpacity(0.40),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BlankSlots extends StatelessWidget {
  final List<int> wordLengths;
  const _BlankSlots({required this.wordLengths});

  @override
  Widget build(BuildContext context) {
    const slotSize = 40.0;
    const gap = 5.0;
    const wordGap = 16.0;

    return Wrap(
      textDirection: TextDirection.rtl,
      alignment: WrapAlignment.center,
      spacing: wordGap,
      runSpacing: 10,
      children: [
        for (final len in wordLengths)
          Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < len; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                _BlankSlot(size: slotSize),
              ],
            ],
          ),
      ],
    );
  }
}

class _BlankSlot extends StatefulWidget {
  final double size;
  const _BlankSlot({required this.size});

  @override
  State<_BlankSlot> createState() => _BlankSlotState();
}

class _BlankSlotState extends State<_BlankSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200 + math.Random().nextInt(800)),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: const Color(0xFF07101F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Color.lerp(
              const Color(0xFFD4AF37).withOpacity(0.20),
              const Color(0xFFD4AF37).withOpacity(0.55),
              _shimmer.value,
            )!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37)
                  .withOpacity(0.04 + _shimmer.value * 0.08),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
