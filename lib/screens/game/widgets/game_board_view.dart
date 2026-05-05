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
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        final tileSize = side / gridSize;
        return Center(
          child: Container(
            width: side,
            height: side,
            color: const Color(0xFF050A14),
            child: Stack(
              children: [
                for (var index = 0; index < gridSize * gridSize; index++)
                  _Tile(
                    index: index,
                    gridSize: gridSize,
                    tileSize: tileSize,
                    imageUrl: imageUrl,
                    isRevealed: revealedCells.contains(index),
                    isAvailable: availableCells.contains(index),
                    enabled: enabled,
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

class _Tile extends StatelessWidget {
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
              child: _ImageSlice(
                index: index,
                gridSize: gridSize,
                tileSize: tileSize,
                imageUrl: imageUrl,
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
