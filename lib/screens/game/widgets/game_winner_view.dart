import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_styles.dart';

class GameWinnerView extends StatefulWidget {
  final String winnerName;
  final VoidCallback onHome;

  const GameWinnerView({
    super.key,
    required this.winnerName,
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
        Padding(
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
  final bool showButton;
  final VoidCallback onHome;

  const _WinnerCard({
    required this.winnerName,
    required this.showButton,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF07101F).withOpacity(0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.72), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.18),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 10),
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
