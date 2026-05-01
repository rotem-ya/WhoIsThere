import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';

const _kTileClosed = 'assets/images/tiles/tile_closed.png';
const _kTileEmpty  = 'assets/images/tiles/tile_closed_empty.png';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  String? _imageUrl;
  String  _loadedImageId = '';

  // Called reactively from build when imageId becomes available or changes.
  Future<void> _loadImage(String imageId) async {
    if (imageId.isEmpty || imageId == _loadedImageId) return;
    _loadedImageId = imageId;
    try {
      if (imageId.startsWith('local_')) {
        // Map local_<name> → assets/images/places/<name>.jpg
        final name = imageId.replaceFirst('local_', '');
        if (mounted) setState(() => _imageUrl = 'assets/images/places/$name.jpg');
        return;
      }
      final img = await ref.read(roomServiceProvider).getImage(imageId);
      if (mounted && img != null) setState(() => _imageUrl = img.imageUrl);
    } catch (e) {
      debugPrint('Failed to load image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1E),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1E), Color(0xFF150A2E), Color(0xFF0D1624)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: roomAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF8B6FFF), strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text('שגיאה: $e',
                  style: const TextStyle(color: Colors.white38)),
            ),
            data: (room) {
              if (room == null) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => context.go('/home'));
                return const SizedBox();
              }
              // Trigger image load whenever imageId is available / changes
              if (room.imageId.isNotEmpty) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _loadImage(room.imageId));
              }
              return _GameLayout(
                room: room,
                imageUrl: _imageUrl,
                onReveal: (i) =>
                    ref.read(roomServiceProvider).revealCell(widget.roomId, i),
                onBack: () => context.go('/home'),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Layout ──────────────────────────────────────────────────────────────────

class _GameLayout extends StatelessWidget {
  final RoomModel room;
  final String?   imageUrl;
  final void Function(int) onReveal;
  final VoidCallback onBack;

  const _GameLayout({
    required this.room,
    required this.imageUrl,
    required this.onReveal,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(code: room.code, onBack: onBack),
        Expanded(
          child: _GameBoard(
            revealedCells: room.revealedCells,
            imageUrl: imageUrl,
            onReveal: onReveal,
          ),
        ),
        const _BottomBar(),
      ],
    );
  }
}

// ─── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String code;
  final VoidCallback onBack;

  const _TopBar({required this.code, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 20, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white60, size: 18),
            onPressed: onBack,
          ),
          const Spacer(),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 11,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Board ───────────────────────────────────────────────────────────────────

class _GameBoard extends StatelessWidget {
  final List<int>      revealedCells;
  final String?        imageUrl;
  final void Function(int) onReveal;

  static const int _gridSize = 5;

  const _GameBoard({
    required this.revealedCells,
    required this.imageUrl,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _gridSize,
                mainAxisSpacing: 0,
                crossAxisSpacing: 0,
              ),
              itemCount: _gridSize * _gridSize,
              itemBuilder: (context, index) {
                if (revealedCells.contains(index)) {
                  return _OpenTile(
                    index: index,
                    gridSize: _gridSize,
                    imageUrl: imageUrl,
                  );
                }
                return GestureDetector(
                  onTap: () => onReveal(index),
                  child: Image.asset(_kTileClosed, fit: BoxFit.cover),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Open tile (image slice) ─────────────────────────────────────────────────

class _OpenTile extends StatelessWidget {
  final int     index;
  final int     gridSize;
  final String? imageUrl;

  const _OpenTile({
    required this.index,
    required this.gridSize,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) {
      return Image.asset(_kTileEmpty, fit: BoxFit.cover);
    }

    final row    = index ~/ gridSize;
    final col    = index % gridSize;
    // Map (row, col) to Alignment in [-1, 1] range
    final xAlign = (col / (gridSize - 1)) * 2.0 - 1.0;
    final yAlign = (row / (gridSize - 1)) * 2.0 - 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSize = constraints.maxWidth;
        final fullSize = tileSize * gridSize;

        final child = imageUrl!.startsWith('assets/')
            ? Image.asset(
                imageUrl!,
                width: fullSize,
                height: fullSize,
                fit: BoxFit.cover,
              )
            : CachedNetworkImage(
                imageUrl: imageUrl!,
                width: fullSize,
                height: fullSize,
                fit: BoxFit.cover,
              );

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment(xAlign, yAlign),
            minWidth: fullSize,
            maxWidth: fullSize,
            minHeight: fullSize,
            maxHeight: fullSize,
            child: child,
          ),
        );
      },
    );
  }
}

// ─── Bottom bar ──────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: const [
          Expanded(child: _GuessButton()),
          SizedBox(width: 12),
          _SkipButton(),
        ],
      ),
    );
  }
}

class _GuessButton extends StatelessWidget {
  const _GuessButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B7EFF), Color(0xFF6B44F8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B5FFF).withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'ניחוש',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Center(
        child: Text(
          'דלג',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
