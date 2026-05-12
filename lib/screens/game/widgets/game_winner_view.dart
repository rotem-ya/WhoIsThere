import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_styles.dart';
import '../../../models/economy/match_reward_breakdown.dart';

class GameWinnerView extends StatefulWidget {
  final String winnerName;
  final String? placeName;
  final MatchRewardBreakdown? rewardBreakdown;
  final VoidCallback onHome;

  const GameWinnerView({
    super.key,
    required this.winnerName,
    this.placeName,
    this.rewardBreakdown,
    required this.onHome,
  });

  @override
  State<GameWinnerView> createState() => _GameWinnerViewState();
}

class _GameWinnerViewState extends State<GameWinnerView> {
  late final ConfettiController _confettiController;
  bool _showCard = false;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _runEntrance();
  }

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _showCard = true);
    _confettiController.play();

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _showButton = true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(child: _WinnerBackground()),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: math.pi / 2,
          emissionFrequency: 0.08,
          numberOfParticles: 18,
          gravity: 0.16,
          shouldLoop: false,
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AnimatedScale(
            scale: _showCard ? 1 : 0.86,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _showCard ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              child: _WinnerCard(
                winnerName: widget.winnerName,
                placeName: widget.placeName,
                rewardBreakdown: widget.rewardBreakdown,
                showButton: _showButton,
                onHome: widget.onHome,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerBackground extends StatelessWidget {
  const _WinnerBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppStyles.backgroundGradient,
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  final String winnerName;
  final String? placeName;
  final MatchRewardBreakdown? rewardBreakdown;
  final bool showButton;
  final VoidCallback onHome;

  const _WinnerCard({
    required this.winnerName,
    this.placeName,
    required this.rewardBreakdown,
    required this.showButton,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF07101F).withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.52), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.50),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 82, height: 1)),
          const SizedBox(height: 14),
          const Text(
            'ניצחון!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$winnerName גילה את המקום',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (placeName != null && placeName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'המקום: $placeName',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'כל הכבוד. זה היה ניחוש מנצח.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (rewardBreakdown != null) ...[
            const SizedBox(height: 18),
            _RewardSummary(breakdown: rewardBreakdown!),
          ],
          const SizedBox(height: 26),
          AnimatedOpacity(
            opacity: showButton ? 1 : 0,
            duration: const Duration(milliseconds: 280),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFA1811A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FilledButton(
                  onPressed: showButton ? onHome : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: const Color(0xFF07101F),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('משחק חדש'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Incremental reward breakdown ──────────────────────────────────────────────

class _RewardSummary extends StatefulWidget {
  final MatchRewardBreakdown breakdown;
  const _RewardSummary({required this.breakdown});

  @override
  State<_RewardSummary> createState() => _RewardSummaryState();
}

class _RewardSummaryState extends State<_RewardSummary> {
  bool _showBase = false;
  bool _showEarlyGuess = false;
  bool _showSpeed = false;
  bool _showNoWrong = false;
  bool _showPerfect = false;
  bool _showPenalty = false;
  bool _showTotal = false;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() => _showBase = true);

    if (widget.breakdown.earlyGuessBonus > 0) {
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() => _showEarlyGuess = true);
    }

    if (widget.breakdown.speedBonus > 0) {
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() => _showSpeed = true);
    }

    if (widget.breakdown.noWrongGuessBonus > 0) {
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() => _showNoWrong = true);
    }

    if (widget.breakdown.perfectRoundBonus > 0) {
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() => _showPerfect = true);
    }

    if (widget.breakdown.wrongGuessPenalty > 0) {
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted) return;
      setState(() => _showPenalty = true);
    }

    await Future.delayed(const Duration(milliseconds: 480));
    if (!mounted) return;
    setState(() => _showTotal = true);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.breakdown;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.18)),
      ),
      child: Column(
        children: [
          _RewardRow(
            label: 'פרס בסיסי',
            coins: b.baseReward,
            visible: _showBase,
            color: Colors.white,
          ),
          if (b.earlyGuessBonus > 0)
            _RewardRow(
              label: '🎯 זיהוי מוקדם',
              coins: b.earlyGuessBonus,
              visible: _showEarlyGuess,
              color: const Color(0xFF87CEEB),
            ),
          if (b.speedBonus > 0)
            _RewardRow(
              label: '⚡ בונוס מהירות',
              coins: b.speedBonus,
              visible: _showSpeed,
              color: const Color(0xFFFFE082),
            ),
          if (b.noWrongGuessBonus > 0)
            _RewardRow(
              label: '✅ ללא טעויות',
              coins: b.noWrongGuessBonus,
              visible: _showNoWrong,
              color: const Color(0xFF81C784),
            ),
          if (b.perfectRoundBonus > 0)
            _RewardRow(
              label: '🌟 פתיחה מושלמת',
              coins: b.perfectRoundBonus,
              visible: _showPerfect,
              color: const Color(0xFFD4AF37),
            ),
          if (b.wrongGuessPenalty > 0)
            _RewardRow(
              label: '❌ קנס טעויות',
              coins: b.wrongGuessPenalty,
              visible: _showPenalty,
              color: const Color(0xFFEF9A9A),
              isNegative: true,
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: _showTotal
                ? Column(
                    children: [
                      const SizedBox(height: 8),
                      _TotalRow(total: b.total),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String label;
  final int coins;
  final bool visible;
  final Color color;
  final bool isNegative;

  const _RewardRow({
    required this.label,
    required this.coins,
    required this.visible,
    required this.color,
    this.isNegative = false,
  });

  @override
  Widget build(BuildContext context) {
    final coinText = isNegative ? '−$coins 🪙' : '+$coins 🪙';
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                textDirection: TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color.withOpacity(0.88),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              coinText,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final int total;
  const _TotalRow({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.46)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'סה"כ',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            '+$total 🪙',
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
