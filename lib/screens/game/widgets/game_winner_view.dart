import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/ad_constants.dart';
import '../../../core/theme/app_styles.dart';
import '../../../models/economy/match_reward_breakdown.dart';
import '../../../widgets/common/banner_ad_widget.dart';
import '../../../widgets/economy/coin_icon.dart';

class GameWinnerView extends StatefulWidget {
  final String winnerName;
  final String? placeName;
  final String? trivia;
  final String? imageUrl;
  final MatchRewardBreakdown? rewardBreakdown;
  final VoidCallback onHome;

  /// Coins this player earned this match — used by the optional "double your
  /// coins" rewarded-ad button. 0 hides the button.
  final int coinsWon;

  /// Opt-in rewarded ad: shows a video, then grants a bonus equal to [coinsWon]
  /// (doubling the winnings). Returns true on success. Null hides the button.
  final Future<bool> Function()? onDoubleCoins;

  const GameWinnerView({
    super.key,
    required this.winnerName,
    this.placeName,
    this.trivia,
    this.imageUrl,
    this.rewardBreakdown,
    required this.onHome,
    this.coinsWon = 0,
    this.onDoubleCoins,
  });

  @override
  State<GameWinnerView> createState() => _GameWinnerViewState();
}

class _GameWinnerViewState extends State<GameWinnerView> {
  late final ConfettiController _confettiController;
  bool _showCard = false;
  bool _showButton = false;
  bool _doubled = false;
  bool _doublingBusy = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _runEntrance();
  }

  Future<void> _handleDouble() async {
    if (_doublingBusy || _doubled || widget.onDoubleCoins == null) return;
    setState(() => _doublingBusy = true);
    final ok = await widget.onDoubleCoins!();
    if (!mounted) return;
    setState(() {
      _doublingBusy = false;
      if (ok) _doubled = true;
    });
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
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, AdConstants.bannersEnabled ? 66 : 12),
          // Single compact screen, no scrolling: the card is laid out at the
          // available width and scaled down (FittedBox) if it would be taller
          // than the viewport, so everything fits without ever scrolling.
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedScale(
                    scale: _showCard ? 1 : 0.86,
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: _showCard ? 1 : 0,
                      duration: const Duration(milliseconds: 260),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: _WinnerCard(
                          winnerName: widget.winnerName,
                          placeName: widget.placeName,
                          trivia: widget.trivia,
                          imageUrl: widget.imageUrl,
                          rewardBreakdown: widget.rewardBreakdown,
                          showButton: _showButton,
                          onHome: widget.onHome,
                          canDouble: widget.onDoubleCoins != null &&
                              widget.coinsWon > 0,
                          coinsWon: widget.coinsWon,
                          doubled: _doubled,
                          doublingBusy: _doublingBusy,
                          onDouble: _handleDouble,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Banner pinned to the bottom of the win screen (outside the scaled
        // card so it renders at its real pixel size). Self-hides when banners
        // are disabled.
        const Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: BannerAdWidget()),
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
  final String? trivia;
  final String? imageUrl;
  final MatchRewardBreakdown? rewardBreakdown;
  final bool showButton;
  final VoidCallback onHome;
  final bool canDouble;
  final int coinsWon;
  final bool doubled;
  final bool doublingBusy;
  final VoidCallback onDouble;

  const _WinnerCard({
    required this.winnerName,
    this.placeName,
    this.trivia,
    this.imageUrl,
    required this.rewardBreakdown,
    required this.showButton,
    required this.onHome,
    required this.canDouble,
    required this.coinsWon,
    required this.doubled,
    required this.doublingBusy,
    required this.onDouble,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
          // The revealed place photo is the hero of the win screen.
          if (imageUrl != null) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.6), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.5),
                child: SizedBox(
                  width: 116,
                  height: 116,
                  child: imageUrl!.startsWith('assets/')
                      ? Image.asset(imageUrl!, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Center(
                            child: Text('🏆', style: TextStyle(fontSize: 40)),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else
            const Text('🏆', style: TextStyle(fontSize: 56, height: 1)),
          const SizedBox(height: 6),
          const Text(
            'ניצחון!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$winnerName גילה את המקום',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (placeName != null && placeName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'המקום: $placeName',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'כל הכבוד. זה היה ניחוש מנצח.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trivia != null && trivia!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1E33).withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2080C0).withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '💡 ידעת?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF87CEEB),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trivia!,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (rewardBreakdown != null) ...[
            const SizedBox(height: 10),
            _RewardSummary(breakdown: rewardBreakdown!),
          ],
          // Opt-in "double your coins" rewarded ad — only ever runs on tap.
          if (canDouble && showButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: doubled
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF143B22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2EBd6B)),
                      ),
                      child: Center(
                        child: Text.rich(
                          TextSpan(
                            text: '🎉 הזכייה הוכפלה! +$coinsWon ',
                            children: [coinSpan(size: 16)],
                          ),
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Color(0xFF8FE0AC),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2EBd6B), Color(0xFF1B8F4D)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: FilledButton(
                        onPressed: doublingBusy ? null : onDouble,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: doublingBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white),
                              )
                            : Text.rich(
                                TextSpan(
                                  text: '🎬 שכפל את הזכייה  +$coinsWon ',
                                  children: [coinSpan(size: 16)],
                                ),
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: 14),
          AnimatedOpacity(
            opacity: showButton ? 1 : 0,
            duration: const Duration(milliseconds: 280),
            child: SizedBox(
              width: double.infinity,
              height: 48,
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
                  child: const Text('חזור לבית'),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    final coinText = isNegative ? '−$coins ' : '+$coins ';
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  style: TextStyle(
                    color: color.withOpacity(0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text.rich(
              TextSpan(
                text: coinText,
                children: [coinSpan(size: 15)],
              ),
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
          Text.rich(
            TextSpan(
              text: '+$total ',
              children: [coinSpan(size: 18, color: Color(0xFFD4AF37))],
            ),
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
