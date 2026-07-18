import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/ad_constants.dart';
import '../../../core/theme/app_styles.dart';
import '../../../models/economy/match_reward_breakdown.dart';
import '../../../models/game_image_model.dart';
import '../../../services/settings_service.dart';
import '../../../services/sfx_service.dart';
import '../../../widgets/common/app_share_badges.dart';
import '../../../widgets/common/banner_ad_widget.dart';
import '../../../widgets/economy/coin_icon.dart';
import 'round_gallery_view.dart';

class GameWinnerView extends StatefulWidget {
  final String winnerName;
  final String? placeName;
  final String? trivia;
  final String? source;
  final String? imageUrl;
  final MatchRewardBreakdown? rewardBreakdown;
  final VoidCallback onHome;

  /// "גילה את המקום" / "ניחש את הפתגם" / "זיהה נכון" — verb phrase after the
  /// winner's name. Defaults to the original place-guessing wording.
  final String winVerb;

  /// "המקום" / "הפתגם" / "התשובה" — label before the answer. Defaults to
  /// the original place-guessing wording.
  final String answerLabel;

  /// Coins this player earned this match — used by the optional "double your
  /// coins" rewarded-ad button. 0 hides the button.
  final int coinsWon;

  /// Opt-in rewarded ad: shows a video, then grants a bonus equal to [coinsWon]
  /// (doubling the winnings). Returns true on success. Null hides the button.
  final Future<bool> Function()? onDoubleCoins;

  /// Friends-game rematch ("play again, same group"). [showRematch] gates the
  /// button; [rematchReady] flips it from "create" to "join" once another
  /// player has already opened the rematch room. Null [onRematch] hides it.
  final bool showRematch;
  final bool rematchReady;
  final Future<void> Function()? onRematch;

  /// Every image played this match (all heat/proverbs rounds, or just the
  /// one for a normal game) — powers the post-match gallery + save button.
  /// Empty hides the gallery entry point.
  final List<GameImageModel> galleryImages;

  /// Store link the gallery's QR badge encodes — resolved by the caller from
  /// the same admin-controlled override (app_config/app) the "share the app"
  /// flow already uses, since the hardcoded default URLs aren't guaranteed to
  /// be live store listings.
  final String galleryStoreUrl;

  const GameWinnerView({
    super.key,
    required this.winnerName,
    this.placeName,
    this.trivia,
    this.source,
    this.imageUrl,
    this.rewardBreakdown,
    required this.onHome,
    this.winVerb = 'גילה את המקום',
    this.answerLabel = 'המקום',
    this.coinsWon = 0,
    this.onDoubleCoins,
    this.showRematch = false,
    this.rematchReady = false,
    this.onRematch,
    this.galleryImages = const [],
    this.galleryStoreUrl = '',
  });

  @override
  State<GameWinnerView> createState() => _GameWinnerViewState();
}

class _GameWinnerViewState extends State<GameWinnerView>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;
  // One-shot gold "detonation" flash that fires the instant the card lands.
  late final AnimationController _flashController;
  final GlobalKey _shareCardKey = GlobalKey();
  bool _showCard = false;
  bool _showButton = false;
  bool _doubled = false;
  bool _doublingBusy = false;
  bool _rematchBusy = false;
  bool _sharingCard = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _runEntrance();
  }

  /// The celebratory "impact" — a triple haptic burst, honoring the user's
  /// vibration setting. Kept out of _runEntrance's async gaps so it fires
  /// exactly on the card landing.
  void _impactHaptic() {
    if (!SettingsService.instance.vibrationEnabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted && SettingsService.instance.vibrationEnabled) {
        HapticFeedback.mediumImpact();
      }
    });
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

  Future<void> _doRematch() async {
    if (_rematchBusy || widget.onRematch == null) return;
    setState(() => _rematchBusy = true);
    try {
      await widget.onRematch!();
    } finally {
      if (mounted) setState(() => _rematchBusy = false);
    }
  }

  /// Captures the win card itself (trophy/title/answer/trivia/reward — not
  /// the action buttons) and shares it as an image, watermarked with the
  /// app logo + a download-QR the same way the round gallery's saves are.
  Future<void> _shareWinCard() async {
    if (_sharingCard) return;
    setState(() => _sharingCard = true);
    try {
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('boundary not ready');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) throw Exception('encode failed');
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: 'whoisthere_win.png')],
        subject: 'מה בתמונה?',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('השיתוף נכשל, נסה שוב')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingCard = false);
    }
  }

  Future<void> _runEntrance() async {
    // Short build-up beat before the impact so the pop lands, not eases in.
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _showCard = true);
    _confettiController.play();
    // Impact: gold flash + haptic burst, together with the card's scale-in.
    _impactHaptic();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) _flashController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _showButton = true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Positioned.fill(child: _WinnerBackground()),
        // One-shot gold detonation flash behind the card, driven by the
        // entrance controller (skipped entirely under "reduce motion").
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flashController,
              builder: (context, _) {
                final t = _flashController.value;
                if (t == 0) return const SizedBox.shrink();
                return Center(
                  child: Opacity(
                    opacity: (1 - t) * 0.5,
                    child: Transform.scale(
                      scale: 0.2 + t * 1.5,
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Color(0x66FBEC9E),
                              Color(0x33D4AF37),
                              Color(0x00D4AF37),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
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
                          source: widget.source,
                          winVerb: widget.winVerb,
                          answerLabel: widget.answerLabel,
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
                          showRematch: widget.showRematch,
                          rematchReady: widget.rematchReady,
                          rematchBusy: _rematchBusy,
                          onRematch: _doRematch,
                          galleryImages: widget.galleryImages,
                          galleryStoreUrl: widget.galleryStoreUrl,
                          shareCardKey: _shareCardKey,
                          sharingCard: _sharingCard,
                          onShareCard: _shareWinCard,
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
        // Premium motion asset (Lottie trophy) crowning the win — plays once
        // on entrance. A proof-of-concept for asset-driven animation vs the
        // hand-rolled particle effects.
        if (_showCard)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Lottie.asset(
                  'assets/lottie/trophy_win.json',
                  width: 128,
                  height: 128,
                  repeat: false,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
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
  final String? source;
  final String winVerb;
  final String answerLabel;
  final String? imageUrl;
  final MatchRewardBreakdown? rewardBreakdown;
  final bool showButton;
  final VoidCallback onHome;
  final bool canDouble;
  final int coinsWon;
  final bool doubled;
  final bool doublingBusy;
  final VoidCallback onDouble;
  final bool showRematch;
  final bool rematchReady;
  final bool rematchBusy;
  final VoidCallback onRematch;
  final List<GameImageModel> galleryImages;
  final String galleryStoreUrl;
  final GlobalKey shareCardKey;
  final bool sharingCard;
  final VoidCallback onShareCard;

  const _WinnerCard({
    required this.winnerName,
    this.placeName,
    this.trivia,
    this.source,
    required this.winVerb,
    required this.answerLabel,
    this.imageUrl,
    required this.rewardBreakdown,
    required this.showButton,
    required this.onHome,
    required this.canDouble,
    required this.coinsWon,
    required this.doubled,
    required this.doublingBusy,
    required this.onDouble,
    required this.showRematch,
    required this.rematchReady,
    required this.rematchBusy,
    required this.onRematch,
    this.galleryImages = const [],
    this.galleryStoreUrl = '',
    required this.shareCardKey,
    required this.sharingCard,
    required this.onShareCard,
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
          // Everything captured by "שתף מסך ניצחון" lives inside this
          // boundary — the trophy/title/answer/trivia/reward, watermarked
          // with the same logo+QR badges the round gallery saves use. The
          // action buttons below are deliberately OUTSIDE it (a shared
          // screenshot with live buttons in it would look broken).
          RepaintBoundary(
            key: shareCardKey,
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
            const Text('🏆', style: TextStyle(fontSize: 46, height: 1)),
          const SizedBox(height: 6),
          const Text(
            'ניצחון!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$winnerName $winVerb',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (placeName != null && placeName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$answerLabel: $placeName',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 13.5,
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
              fontSize: 12,
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
                  if (source != null && source!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      source!,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (rewardBreakdown != null) ...[
            const SizedBox(height: 10),
            _RewardSummary(breakdown: rewardBreakdown!),
          ],
          if (galleryStoreUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogoBadge(),
                const SizedBox(width: 8),
                AppQrBadge(storeUrl: galleryStoreUrl, size: 38),
              ],
            ),
          ],
              ],
            ),
          ),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(
                                text: '🎉 הזכייה הוכפלה! +$coinsWon ',
                                children: [coinSpan(size: 15)],
                              ),
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                color: Color(0xFF8FE0AC),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text.rich(
                                  TextSpan(
                                    text: '🎬 שכפל את הזכייה  +$coinsWon ',
                                    children: [coinSpan(size: 15)],
                                  ),
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                      ),
                    ),
            ),
          ],
          // Friends "play again": regroups the same lobby. First tapper creates
          // the rematch room; everyone else sees "join rematch".
          if (showRematch && showButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20A8E0), Color(0xFF0868A8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FilledButton(
                  onPressed: rematchBusy ? null : onRematch,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: rematchBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rematchReady
                                ? '➡️ הצטרף למשחק חוזר'
                                : '🔄 שחק שוב',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                ),
              ),
            ),
          ],
          if (galleryImages.isNotEmpty && showButton) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RoundGalleryView(
                            images: galleryImages,
                            answerLabel: answerLabel,
                            storeUrl: galleryStoreUrl,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF87CEEB),
                        side: BorderSide(
                            color: const Color(0xFF87CEEB).withOpacity(0.7)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: const [
                            Icon(Icons.photo_library_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('גלריית הסבב ושמירה',
                                textDirection: TextDirection.rtl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Shares the win card itself (title/answer/trivia/reward) —
                // distinct from the gallery's per-round photo share.
                SizedBox(
                  width: 46,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: sharingCard ? null : onShareCard,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      side: BorderSide(
                          color: const Color(0xFFD4AF37).withOpacity(0.7)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: EdgeInsets.zero,
                    ),
                    child: sharingCard
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Color(0xFFD4AF37)),
                          )
                        : const Icon(Icons.ios_share_rounded),
                  ),
                ),
              ],
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
    // Climax of the reward tally: a coin flourish + a satisfying tap.
    SfxService.instance.coinGain();
    if (SettingsService.instance.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
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
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: total),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, value, _) => Text.rich(
              TextSpan(
                text: '+$value ',
                children: [coinSpan(size: 18, color: Color(0xFFD4AF37))],
              ),
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
