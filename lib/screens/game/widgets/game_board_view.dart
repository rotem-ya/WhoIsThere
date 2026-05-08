import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../utils/game_constants.dart';
import '../../../widgets/game/aperture_tile.dart';

const Duration _kApertureDuration = Duration(milliseconds: 1500);

class GameBoardView extends StatefulWidget {
  final int gridSize;
  final List<int> revealedCells;
  final List<int> availableCells;
  final String? imageUrl;
  final bool enabled;
  final bool glowEnabled;
  final void Function(int)? onReveal;

  const GameBoardView({
    super.key,
    required this.gridSize,
    required this.revealedCells,
    required this.availableCells,
    required this.imageUrl,
    required this.enabled,
    required this.glowEnabled,
    required this.onReveal,
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
              color: kNavyBlack,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.enabled ? kCyan.withOpacity(0.15) : Colors.transparent,
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

  const _Tile({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.imageUrl,
    required this.isRevealed,
    required this.isAvailable,
    required this.enabled,
    required this.onReveal,
  });

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  bool _pressed = false;

  static final AssetSource _revealSound = AssetSource('sounds/aperture_open.mp3');
  static final AudioPlayer _revealPlayer = AudioPlayer(playerId: 'aperture-reveal');
  static Future<void>? _preloadFuture;

  bool get _canTap => widget.enabled && widget.isAvailable && !widget.isRevealed && widget.onReveal != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_preloadRevealSound());
  }

  static Future<void> _preloadRevealSound() async {
    _preloadFuture ??= _revealPlayer.setSource(_revealSound);
    await _preloadFuture;
  }

  static Future<void> _playRevealSound() async {
    try {
      await _revealPlayer.stop();
      await _revealPlayer.play(_revealSound);
    } catch (_) {
      // Sound failure must never block reveal
    }
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
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _canTap
              ? (_) {
                  HapticFeedback.lightImpact();
                  _setPressed(true);
                }
              : null,
          onTapCancel: () => _setPressed(false),
          onTapUp: _canTap
              ? (_) {
                  _setPressed(false);
                  unawaited(_playRevealSound());
                  widget.onReveal!(widget.index);
                }
              : null,
          child: AnimatedOpacity(
            duration: kRevealDuration,
            opacity: 1.0,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.index),
              tween: Tween<double>(begin: widget.isRevealed ? 1.08 : 1.0, end: 1.0),
              duration: kRevealDuration,
              curve: Curves.easeOutCubic,
              builder: (context, revealScale, child) {
                return AnimatedScale(
                  scale: _pressed ? kTapScale : revealScale,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOutCubic,
                  child: child,
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: widget.isRevealed
                      ? [
                          BoxShadow(
                            color: kCyan.withOpacity(0.22),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: ApertureTile(
                  isRevealed: widget.isRevealed,
                  isFocused: _canTap,
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
        ),
      ),
    );
  }
}

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
