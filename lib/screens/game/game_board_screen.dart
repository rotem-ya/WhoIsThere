import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../models/room_model.dart';
import '../../providers/providers.dart';
import '../../services/room_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  bool _isActing = false;
  bool _hasFlipped = false;

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomProvider(widget.roomId));
    final authState = ref.watch(firebaseUserProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/auth');
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return roomAsync.when(
          data: (room) => _buildGameScreen(context, room, user.uid),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('שגיאה: $e')),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }

  Widget _buildGameScreen(BuildContext context, RoomModel room, String userId) {
    if (room.state != RoomState.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (room.state == RoomState.lobby) {
          context.go('/room/${room.id}');
        } else if (room.state == RoomState.finished) {
          context.go('/win/${room.id}');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUserId = room.currentTurnUserId;
    final isMyTurn = currentUserId == userId;
    final canSubmitAnswer = isMyTurn && !_isActing;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: room.name,
              onBack: () => _confirmExit(context, userId),
              trailing: IconButton(
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white),
                onPressed: () => _confirmExit(context, userId),
              ),
            ),
            const SizedBox(height: 4),
            _PlayersStrip(
              room: room,
              compact: MediaQuery.of(context).size.height < 700,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return _ImageRevealBoard(
                            imageUrl: room.currentImageUrl,
                            revealedCells: room.revealedCells,
                            onCellTap: isMyTurn && !_hasFlipped
                                ? (index) => _flipCell(room, index)
                                : null,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (canSubmitAnswer) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ניחוש שגוי יעלה מטבעות',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppButton(
                        label: 'נחש',
                        icon: Icons.psychology_alt_rounded,
                        onPressed: () => _openGuessSheet(room),
                      ),
                      if (_hasFlipped)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.secondary.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isActing ? null : _endTurn,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.skip_next_rounded,
                                        size: 20,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'דלג על הניחוש',
                                        style: AppTextStyles.body.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'לצאת מהמשחק?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text('תאבד את ההתקדמות שלך בסיבוב זה.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(roomServiceProvider).leaveRoom(widget.roomId, userId);
              context.go('/home');
            },
            child: const Text('עזוב', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _flipCell(RoomModel room, int cellIndex) async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      await ref.read(roomServiceProvider).revealCell(room.id, cellIndex);
      if (mounted) setState(() => _hasFlipped = true);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _openGuessSheet(RoomModel room) {
    // existing logic
  }

  Future<void> _endTurn() async {
    if (_isActing) return;
    setState(() => _isActing = true);
    try {
      await ref.read(roomServiceProvider).endTurn(widget.roomId);
      if (mounted) setState(() => _hasFlipped = false);
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }
}

class _PlayersStrip extends StatelessWidget {
  final RoomModel room;
  final bool compact;

  const _PlayersStrip({required this.room, required this.compact});

  @override
  Widget build(BuildContext context) {
    final players = room.sortedPlayers.take(10).toList();
    return IntrinsicHeight(
      child: Row(
        children: players.map((player) {
          final isCurrentTurn = room.currentTurnUserId == player.id;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(
                vertical: compact ? 1 : 2,
                horizontal: compact ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: isCurrentTurn
                    ? AppColors.accent.withOpacity(compact ? 0.30 : 0.24)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(compact ? 999 : 12),
                border: Border.all(
                  color: isCurrentTurn
                      ? Colors.white.withOpacity(0.82)
                      : Colors.white.withOpacity(0.10),
                  width: isCurrentTurn ? 1.5 : 0.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PlayerAvatar(
                    name: player.name,
                    photoUrl: player.photoUrl,
                    radius: compact ? 8 : 10,
                    isCurrentTurn: isCurrentTurn,
                    isEliminated: player.isEliminated,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        height: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ImageRevealBoard extends StatelessWidget {
  final String imageUrl;
  final Set<int> revealedCells;
  final void Function(int)? onCellTap;

  const _ImageRevealBoard({
    required this.imageUrl,
    required this.revealedCells,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.darkBlue,
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.white54),
                    ),
                  ),
                ),
              ),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: 25,
                itemBuilder: (context, index) {
                  final isRevealed = revealedCells.contains(index);
                  final canTap = onCellTap != null && !isRevealed;
                  
                  String assetPath;
                  if (isRevealed) {
                    assetPath = 'assets/images/tile_open.png';
                  } else if (canTap) {
                    assetPath = 'assets/images/tile_closed.png';
                  } else {
                    assetPath = 'assets/images/tile_closed_empty.png';
                  }

                  return GestureDetector(
                    onTap: canTap ? () => onCellTap!(index) : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
