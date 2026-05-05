import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../widgets/game/vault_gem_tile.dart';

class GameBoardView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final totalCells = gridSize * gridSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final tileSize = side / gridSize;

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _FullBoardImage(imageUrl: imageUrl),
                for (var index = 0; index < totalCells; index++)
                  _BoardTileOverlay(
                    index: index,
                    gridSize: gridSize,
                    tileSize: tileSize,
                    isRevealed: revealedCells.contains(index),
                    isAvailable: availableCells.contains(index),
                    enabled: enabled,
                    glowEnabled: glowEnabled,
                    onReveal: onReveal,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FullBoardImage extends StatelessWidget {
  final String? imageUrl;

  const _FullBoardImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return const _ImageFallback();

    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _ImageFallback(),
    );
  }
}

class _BoardTileOverlay extends StatelessWidget {
  final int index;
  final int gridSize;
  final double tileSize;
  final bool isRevealed;
  final bool isAvailable;
  final bool enabled;
  final bool glowEnabled;
  final void Function(int)? onReveal;

  const _BoardTileOverlay({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.isRevealed,
    required this.isAvailable,
    required this.enabled,
    required this.glowEnabled,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final row = index ~/ gridSize;
    final col = index % gridSize;
    final canTap = enabled && isAvailable && !isRevealed && onReveal != null;

    return Positioned(
      left: col * tileSize,
      top: row * tileSize,
      width: tileSize,
      height: tileSize,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canTap ? () => onReveal!(index) : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: isAvailable || isRevealed ? 1.0 : 0.45,
            child: VaultGemTile(
              isRevealed: isRevealed,
              child: _RevealedTileFrame(glowEnabled: glowEnabled),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealedTileFrame extends StatelessWidget {
  final bool glowEnabled;

  const _RevealedTileFrame({required this.glowEnabled});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: glowEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF87CEEB).withOpacity(0.12),
                  blurRadius: 6,
                ),
              ]
            : const [],
      ),
      child: const SizedBox.expand(),
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
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.white24,
          size: 48,
        ),
      ),
    );
  }
}
