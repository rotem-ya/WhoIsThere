import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../utils/game_constants.dart';
import '../../../widgets/game/vault_cover.dart';

const Duration _kApertureDuration = Duration(milliseconds: 600);

class GameBoardView extends StatefulWidget {
  final int gridSize;
  final List<int> revealedCells;
  final List<int> availableCells;
  final String? imageUrl;
  final bool enabled;
  final bool glowEnabled;
  final void Function(int)? onReveal;
  final String cardSkinId;
  final int? pendingRevealTileIndex;
  final int? revealDeadlineMs;
  // Tiles to flash as a dim peek (spotlight tool) — shown over the cover
  // without counting as a real reveal. Cleared by the parent after a moment.
  final Set<int> spotlightCells;

  final VoidCallback? onTapRevealed;

  const GameBoardView({
    super.key,
    required this.gridSize,
    required this.revealedCells,
    required this.availableCells,
    required this.imageUrl,
    required this.enabled,
    required this.glowEnabled,
    required this.onReveal,
    this.onTapRevealed,
    this.cardSkinId = 'default',
    this.pendingRevealTileIndex,
    this.revealDeadlineMs,
    this.spotlightCells = const {},
  });

  @override
  State<GameBoardView> createState() => _GameBoardViewState();
}

class _GameBoardViewState extends State<GameBoardView> {
  bool _locked = false;

  void _handleReveal(int index) {
    if (_locked) return;
    setState(() => _locked = true);
    widget.onReveal?.call(index);
    Future.delayed(_kApertureDuration, () {
      if (mounted) setState(() => _locked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final tileSize = side / widget.gridSize;
        return Center(
          child: AnimatedContainer(
            duration: kRevealDuration,
            width: side,
            height: side,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.enabled ? kCyan.withOpacity(0.55) : Colors.transparent,
                width: 1,
              ),
            ),
            child: ColorFiltered(
              colorFilter: widget.enabled
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                  : const ColorFilter.matrix(<double>[
                      0.95, 0, 0, 0, 0,
                      0, 0.95, 0, 0, 0,
                      0, 0, 0.95, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
              child: IgnorePointer(
                ignoring: _locked,
                child: Stack(
                  children: [
                    for (var index = 0; index < widget.gridSize * widget.gridSize; index++)
                      _Tile(
                        index: index,
                        gridSize: widget.gridSize,
                        tileSize: tileSize,
                        imageUrl: widget.imageUrl,
                        isRevealed: widget.revealedCells.contains(index),
                        isAvailable: widget.availableCells.contains(index),
                        enabled: widget.enabled,
                        onReveal: widget.onReveal != null ? _handleReveal : null,
                        onTapRevealed: widget.onTapRevealed,
                        cardSkinId: widget.cardSkinId,
                        isPendingReveal: index == widget.pendingRevealTileIndex,
                        revealDeadlineMs: widget.revealDeadlineMs,
                        spotlightPeek: widget.spotlightCells.contains(index),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatefulWidget {
  final int index;
  final int gridSize;
  final double tileSize;
  final String? imageUrl;
  final bool isRevealed;
  final bool isAvailable;
  final bool enabled;
  final void Function(int)? onReveal;
  final VoidCallback? onTapRevealed;
  final String cardSkinId;
  final bool isPendingReveal;
  final int? revealDeadlineMs;
  final bool spotlightPeek;

  const _Tile({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.imageUrl,
    required this.isRevealed,
    required this.isAvailable,
    required this.enabled,
    required this.onReveal,
    this.onTapRevealed,
    this.cardSkinId = 'default',
    this.isPendingReveal = false,
    this.revealDeadlineMs,
    this.spotlightPeek = false,
  });

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _popCtrl;
  late Animation<double> _popScale;
  Timer? _countdownTimer;
  int _secondsLeft = 10;

  @override
  void initState() {
    super.initState();
    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // Bounce: 1.0 → 1.10 → 0.96 → 1.0
    _popScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.10), weight: 28),
      TweenSequenceItem(tween: Tween(begin: 1.10, end: 0.96), weight: 32),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 40),
    ]).animate(_popCtrl);
    if (widget.isPendingReveal) _startCountdown();
  }

  @override
  void didUpdateWidget(_Tile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _popCtrl.forward(from: 0.0);
    }
    if (widget.isPendingReveal && !oldWidget.isPendingReveal) {
      _startCountdown();
    } else if (!widget.isPendingReveal && oldWidget.isPendingReveal) {
      _stopCountdown();
    } else if (widget.isPendingReveal && widget.revealDeadlineMs != oldWidget.revealDeadlineMs) {
      _updateSecondsLeft();
    }
  }

  void _startCountdown() {
    _updateSecondsLeft();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) _updateSecondsLeft();
    });
  }

  void _updateSecondsLeft() {
    final deadline = widget.revealDeadlineMs;
    if (deadline == null) return;
    final remaining = deadline - DateTime.now().millisecondsSinceEpoch;
    final secs = (remaining / 1000).ceil().clamp(0, 10);
    if (mounted && secs != _secondsLeft) setState(() => _secondsLeft = secs);
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _popCtrl.dispose();
    super.dispose();
  }

  bool get _canTap =>
      widget.enabled &&
      widget.isAvailable &&
      !widget.isRevealed &&
      widget.onReveal != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.index ~/ widget.gridSize;
    final col = widget.index % widget.gridSize;

    return Positioned(
      left: col * widget.tileSize,
      top: row * widget.tileSize,
      width: widget.tileSize,
      height: widget.tileSize,
      child: AnimatedBuilder(
        animation: _popScale,
        builder: (context, child) => Transform.scale(
          scale: _pressed ? kTapScale : _popScale.value,
          child: child,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _canTap
              ? (_) {
                  HapticFeedback.lightImpact();
                  _setPressed(true);
                }
              : widget.isRevealed
                  ? (_) {
                      HapticFeedback.selectionClick();
                      widget.onTapRevealed?.call();
                    }
                  : (_) => HapticFeedback.selectionClick(),
          onTapCancel: () => _setPressed(false),
          onTapUp: _canTap
              ? (_) {
                  _setPressed(false);
                  widget.onReveal!(widget.index);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              border: _canTap
                  ? Border.all(color: kCyan.withOpacity(0.80), width: 1.5)
                  : null,
              boxShadow: _canTap
                  ? [
                      BoxShadow(
                        color: kCyan.withOpacity(0.40),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                VaultCover(
                  isRevealed: widget.isRevealed,
                  isFocused: _canTap,
                  cardSkinId: widget.cardSkinId,
                  child: _ImageSlice(
                    index: widget.index,
                    gridSize: widget.gridSize,
                    tileSize: widget.tileSize,
                    imageUrl: widget.imageUrl,
                  ),
                ),
                // Spotlight peek — a dim, ghostly flash of the hidden slice over
                // the closed cover. Not a real reveal; the parent clears it.
                if (widget.spotlightPeek && !widget.isRevealed)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: 0.25,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: kCyan.withOpacity(0.55),
                              width: 1,
                            ),
                          ),
                          child: _ImageSlice(
                            index: widget.index,
                            gridSize: widget.gridSize,
                            tileSize: widget.tileSize,
                            imageUrl: widget.imageUrl,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.isPendingReveal && !widget.isRevealed)
                  Positioned.fill(
                    child: _CountdownOverlay(
                      secondsLeft: _secondsLeft,
                      tileSize: widget.tileSize,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Countdown overlay ────────────────────────────────────────────────────────

class _CountdownOverlay extends StatelessWidget {
  final int secondsLeft;
  final double tileSize;

  const _CountdownOverlay({required this.secondsLeft, required this.tileSize});

  @override
  Widget build(BuildContext context) {
    final isUrgent = secondsLeft <= 2;
    final ringColor = isUrgent ? AppColors.danger : AppColors.primary;
    final ringSize = tileSize * 0.60;

    return Container(
      color: const Color(0xF0050A14),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: ringSize,
              height: ringSize,
              child: CircularProgressIndicator(
                value: secondsLeft / 10.0,
                strokeWidth: tileSize * 0.055,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                strokeCap: StrokeCap.round,
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$secondsLeft',
                key: ValueKey(secondsLeft),
                style: TextStyle(
                  color: ringColor,
                  fontSize: tileSize * 0.34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: [
                    Shadow(
                      color: ringColor.withOpacity(0.55),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image slice ───────────────────────────────────────────────────────────────

class _ImageSlice extends StatelessWidget {
  final int index;
  final int gridSize;
  final double tileSize;
  final String? imageUrl;

  const _ImageSlice({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return const _ImageFallback();
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final x = gridSize <= 1 ? 0.0 : (col / (gridSize - 1)) * 2.0 - 1.0;
    final y = gridSize <= 1 ? 0.0 : (row / (gridSize - 1)) * 2.0 - 1.0;
    final full = tileSize * gridSize;
    final image = url.startsWith('assets/')
        ? Image.asset(url, width: full, height: full, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: url,
            width: full,
            height: full,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => const _ImageFallback(),
          );
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment(x, y),
        minWidth: full,
        maxWidth: full,
        minHeight: full,
        maxHeight: full,
        child: image,
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A3E),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 48),
      ),
    );
  }
}
