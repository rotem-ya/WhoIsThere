import 'dart:math' show min;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _kTileClosed = 'assets/images/tiles/tile_closed.png';
const _kTileEmpty = 'assets/images/tiles/tile_closed_empty.png';

class GameBoardView extends StatelessWidget {
  final int gridSize;
  final List<int> revealedCells;
  final List<int> availableCells;
  final String? imageUrl;
  final bool enabled;
  final bool glowEnabled;
  final void Function(int)? onReveal;

  const GameBoardView({
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
        final tile =
            (min(constraints.maxWidth, constraints.maxHeight) * 0.96 / gridSize)
                .floorToDouble();
        final side = tile * gridSize;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: glowEnabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B6FFF).withOpacity(0.40),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: SizedBox.square(
            dimension: side,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl == null)
                    Image.asset(_kTileEmpty, fit: BoxFit.cover)
                  else if (imageUrl!.startsWith('assets/'))
                    Image.asset(imageUrl!, fit: BoxFit.cover)
                  else
                    CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const _BoardImageFallback(),
                    ),
                  for (var index = 0; index < gridSize * gridSize; index++)
                    if (!revealedCells.contains(index))
                      _ClosedTileOverlay(
                        index: index,
                        gridSize: gridSize,
                        tileSize: tile,
                        glowEnabled: glowEnabled,
                        enabled: enabled &&
                            availableCells.contains(index) &&
                            onReveal != null,
                        onTap: onReveal == null ? null : () => onReveal!(index),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClosedTileOverlay extends StatelessWidget {
  final int index;
  final int gridSize;
  final double tileSize;
  final bool enabled;
  final bool glowEnabled;
  final VoidCallback? onTap;

  const _ClosedTileOverlay({
    required this.index,
    required this.gridSize,
    required this.tileSize,
    required this.enabled,
    required this.glowEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = index ~/ gridSize;
    final col = index % gridSize;

    return Positioned(
      left: col * tileSize,
      top: row * tileSize,
      width: tileSize,
      height: tileSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          color: const Color(0xFF15183D),
          foregroundDecoration: glowEnabled
              ? BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF8B6FFF).withOpacity(0.42),
                    width: 1,
                  ),
                )
              : null,
          child: ClipRect(
            child: Transform.scale(
              scale: 1.08,
              child: Image.asset(
                _kTileClosed,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _BoardImageFallback extends StatelessWidget {
  const _BoardImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF15183D),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_rounded,
        color: Colors.white.withOpacity(0.35),
        size: 42,
      ),
    );
  }
}
