import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';

class GameBoardScreen extends ConsumerWidget {
  final String roomId;
  const GameBoardScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));

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
            onReveal: (index) =>
                ref.read(roomServiceProvider).revealCell(roomId, index),
          );
        },
      ),
    );
  }
}

class _GameGrid extends StatelessWidget {
  final RoomModel room;
  final void Function(int index) onReveal;

  const _GameGrid({required this.room, required this.onReveal});

  static const int _gridSize = 5;

  @override
  Widget build(BuildContext context) {
    final revealedCells = room.revealedCells;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridSize,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: _gridSize * _gridSize,
            itemBuilder: (context, index) {
              final isRevealed = revealedCells.contains(index);
              return GestureDetector(
                onTap: isRevealed ? null : () => onReveal(index),
                child: ColoredBox(
                  color: isRevealed
                      ? Colors.green.shade200
                      : Colors.blue.shade600,
                  child: isRevealed
                      ? null
                      : const Center(
                          child: Icon(Icons.question_mark,
                              color: Colors.white, size: 20),
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
