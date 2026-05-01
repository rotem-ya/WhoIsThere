import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';

const _kTileClosed = 'assets/images/tiles/tile_closed.png';
const _kTileEmpty  = 'assets/images/tiles/tile_closed_empty.png';
const _kTileOpen   = 'assets/images/tiles/tile_open.png';
const _kTileActive = 'assets/images/tiles/tile_active.png';
const _kSpacing    = 6.0;
const _kRadius     = BorderRadius.all(Radius.circular(16));

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;
  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  String? _imageUrl;
  int?    _selectedIndex;

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

  void _onTileTap(int index) {
    setState(() => _selectedIndex = index);
    ref.read(roomServiceProvider).revealCell(widget.roomId, index);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _selectedIndex = null);
    });
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
              return _GameLayout(
                room: room,
                imageUrl: _imageUrl,
                selectedIndex: _selectedIndex,
                onTileTap: _onTileTap,
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
  final int?      selectedIndex;
  final void Function(int) onTileTap;
  final VoidCallback onBack;

  const _GameLayout({
    required this.room,
    required this.imageUrl,
    required this.selectedIndex,
    required this.onTileTap,
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
            selectedIndex: selectedIndex,
            onTileTap: onTileTap,
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
  final int?           selectedIndex;
  final void Function(int) onTileTap;

  static const int _gridSize = 5;

  const _GameBoard({
    required this.revealedCells,
    required this.imageUrl,
    required this.selectedIndex,
    required this.onTileTap,
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
                mainAxisSpacing: _kSpacing,
                crossAxisSpacing: _kSpacing,
              ),
              itemCount: _gridSize * _gridSize,
              itemBuilder: (context, index) {
                // Revealed tile — shows image slice
                if (revealedCells.contains(index)) {
                  return _OpenTile(
                    index: index,
                    gridSize: _gridSize,
                    imageUrl: imageUrl,
                  );
                }

                // Active tile — briefly highlighted when tapped
                if (selectedIndex == index) {
                  return ClipRRect(
                    borderRadius: _kRadius,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(_kTileActive, fit: BoxFit.cover),
                    ),
                  );
                }

                // Closed tile — tappable
                return GestureDetector(
                  onTap: () => onTileTap(index),
                  child: ClipRRect(
                    borderRadius: _kRadius,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(_kTileClosed, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Tiles ───────────────────────────────────────────────────────────────────

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
    // No image loaded yet — show empty frame
    if (imageUrl == null) {
      return ClipRRect(
        borderRadius: _kRadius,
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(_kTileEmpty, fit: BoxFit.cover),
        ),
      );
    }

    final row    = index ~/ gridSize;
    final col    = index % gridSize;
    final xAlign = (col / (gridSize - 1)) * 2.0 - 1.0;
    final yAlign = (row / (gridSize - 1)) * 2.0 - 1.0;

    return ClipRRect(
      borderRadius: _kRadius,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final tileSize = constraints.maxWidth;
                final fullSize = tileSize * gridSize;
                return ClipRect(
                  child: OverflowBox(
                    alignment: Alignment(xAlign, yAlign),
                    minWidth: fullSize,
                    maxWidth: fullSize,
                    minHeight: fullSize,
                    maxHeight: fullSize,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: fullSize,
                      height: fullSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
            Opacity(
              opacity: 0.5,
              child: Image.asset(_kTileOpen, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
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
