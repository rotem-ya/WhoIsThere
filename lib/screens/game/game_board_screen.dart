import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage());
  }

  Future<void> _loadImage() async {
    try {
      final room = await ref.read(roomStreamProvider(widget.roomId).future);
      if (room == null || room.imageId.isEmpty) return;
      final img = await ref.read(roomServiceProvider).getImage(room.imageId);
      if (mounted && img != null) setState(() => _imageUrl = img.imageUrl);
    } catch (e) {
      debugPrint('Failed to load image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Game'),
      ),
      body: roomAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (room) {
          if (room == null) return const Center(child: Text('Room not found'));
          return _GameGrid(
            room: room,
            imageUrl: _imageUrl,
            onReveal: (index) =>
                ref.read(roomServiceProvider).revealCell(widget.roomId, index),
          );
        },
      ),
    );
  }
}

class _GameGrid extends StatelessWidget {
  final RoomModel room;
  final String? imageUrl;
  final void Function(int) onReveal;

  const _GameGrid({
    required this.room,
    required this.imageUrl,
    required this.onReveal,
  });

  static const int _gridSize = 5;

  @override
  Widget build(BuildContext context) {
    final revealedCells = room.revealedCells;

    return Center(
      child: AspectRatio(
        aspectRatio: 1,
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
            final isRevealed = revealedCells.contains(index);

            if (isRevealed) {
              return _OpenTile(
                index: index,
                gridSize: _gridSize,
                imageUrl: imageUrl,
              );
            }

            return GestureDetector(
              key: ValueKey('tile_$index'),
              onTap: () => onReveal(index),
              child: Image.asset(
                'assets/images/tiles/tile_closed.png',
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ),
    );
  }
}

// Revealed tile: crops only its (row, col) slice of the game image,
// then overlays tile_open.png (transparent-centre frame) on top.
class _OpenTile extends StatelessWidget {
  final int index;
  final int gridSize;
  final String? imageUrl;

  const _OpenTile({
    required this.index,
    required this.gridSize,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final row = index ~/ gridSize;
    final col = index % gridSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          LayoutBuilder(
            builder: (context, constraints) {
              final tileSize = constraints.maxWidth;
              final fullSize = tileSize * gridSize;
              return ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: fullSize,
                  maxWidth: fullSize,
                  minHeight: fullSize,
                  maxHeight: fullSize,
                  child: Transform.translate(
                    offset: Offset(-col * tileSize, -row * tileSize),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: fullSize,
                      height: fullSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        Image.asset(
          'assets/images/tiles/tile_open.png',
          fit: BoxFit.cover,
        ),
      ],
    );
  }
}
