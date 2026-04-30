import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../models/game_image_model.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/game/letter_bank_input.dart';

class GameBoardScreen extends ConsumerStatefulWidget {
  final String roomId;

  const GameBoardScreen({super.key, required this.roomId});

  @override
  ConsumerState<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends ConsumerState<GameBoardScreen> {
  bool _hasFlipped = false;
  bool _isActing = false;
  GameImageModel? _gameImage;
  bool _imageLoadStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImage());
  }

  Future<void> _loadImage() async {
    if (_imageLoadStarted) return;
    _imageLoadStarted = true;
    try {
      final room = await ref.read(roomStreamProvider(widget.roomId).future);
      if (room?.selectedImageId == null) return;
      final img =
          await ref.read(roomServiceProvider).getImage(room!.selectedImageId!);
      if (mounted) setState(() => _gameImage = img);
    } catch (e) {
      debugPrint('Failed to load game image: $e');
    }
  }

  String _actingUserId(RoomModel room) {
    final user = ref.read(currentUserProvider).value;
    return room.currentTurnUserId ?? user?.id ?? '';
  }

  Future<void> _flipPiece(int pieceIndex, RoomModel room) async {
    if (_hasFlipped || _isActing) return;
    final difficulty = room.selectedDifficulty!;
    AppFeedback.reveal();
    setState(() => _isActing = true);

    try {
      await ref.read(roomServiceProvider).revealPiece(
            roomId: widget.roomId,
            userId: _actingUserId(room),
            pieceIndex: pieceIndex,
            difficulty: difficulty,
          );
      if (mounted) {
        setState(() {
          _hasFlipped = true;
          _isActing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _endTurn() async {
    if (_isActing) return;
    AppFeedback.warning();
    setState(() => _isActing = true);
    try {
      await ref
          .read(roomServiceProvider)
          .skipPiecePlacement(roomId: widget.roomId);
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
          _hasFlipped = false;
        });
      }
    }
  }

  Future<bool> _onAnswerComplete(RoomModel room, String filled) async {
    if (_gameImage == null) return false;
    try {
      final ok = await ref.read(roomServiceProvider).submitAnswer(
            roomId: widget.roomId,
            userId: _actingUserId(room),
            guess: filled,
            image: _gameImage!,
            difficulty: room.selectedDifficulty!,
          );
      if (ok) {
        AppFeedback.success();
      } else {
        AppFeedback.error();
      }
      return ok;
    } catch (_) {
      AppFeedback.error();
      return false;
    }
  }

  Future<void> _openGuessSheet(RoomModel room) async {
    if (_gameImage == null) return;
    AppFeedback.primary();

    final penalty = room.selectedDifficulty?.wrongGuessPenalty ?? 0;

    await AppBottomSheet.show<void>(
      context: context,
      child: SizedBox(
        // Use up to 52 % of screen height; cap at 400 to leave room on large
        // screens. The bottom sheet is isScrollControlled so it can grow.
        height: math.min(MediaQuery.of(context).size.height * 0.52, 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wrong-guess cost warning – clearly visible before submitting
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'ניחוש שגוי יעלה $penalty מטבעות',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: const Color(0xFF7A4F00),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LetterBankInput(
                key: ValueKey('lbi_sheet_${_gameImage!.id}'),
                answer: _gameImage!.answer,
                enabled: true,
                onComplete: (filled) => _onAnswerComplete(room, filled),
              ),
            ),
            // Skip button: high contrast so it's never missed
            TextButton.icon(
              onPressed: _isActing
                  ? null
                  : () {
                      Navigator.pop(context);
                      _endTurn();
                    },
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: const Text('דלג על הניחוש'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                textStyle: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _gridSizeFor(Difficulty difficulty) {
    switch (difficulty) {
      case Difficulty.veryEasy:
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 7;
      case Difficulty.hard:
        return 9;
    }
  }

  double _revealedRatio(RoomModel room, int gridSize) {
    final total = math.max(1, gridSize * gridSize);
    return (room.placedPieces.length / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        if (room.phase == GamePhase.finished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/win/${widget.roomId}');
          });
        }

        if (currentUser == null) return const SizedBox();

        final difficulty = room.selectedDifficulty ?? Difficulty.easy;
        final gridSize = _gridSizeFor(difficulty);
        final currentPlayer = room.players[room.currentTurnUserId];
        final isVirtualTurn = currentPlayer?.isBot == true;
        final isMyTurn =
            room.currentTurnUserId == currentUser.id || isVirtualTurn;
        final myPlayer = room.players[currentUser.id];
        final allRevealed = room.availablePieceIndices.isEmpty;
        final canFlipPiece =
            isMyTurn && !_hasFlipped && !allRevealed && !_isActing;
        final isEliminated = myPlayer?.isEliminated == true;
        // Guessing is optional and always available when it's your turn –
        // the player is never forced to guess after flipping.
        final canSubmitAnswer = isMyTurn && !isEliminated && !_isActing;
        final ratio = _revealedRatio(room, gridSize);
        final imageScale = (1.0 - ratio * 0.07).clamp(0.93, 1.0);

        return AppScaffold(
          backgroundGradient: AppColors.pageBackground,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Stack(
            children: [
              // Animated background that shifts as pieces are revealed
              Positioned.fill(
                child: _GameBackground(revealedRatio: ratio),
              ),
              Column(
                children: [
                  // Header – fixed intrinsic height (48 px from AppHeader)
                  AppHeader(
                    title: isVirtualTurn
                        ? '${currentPlayer?.name ?? '...'} משחק'
                        : isMyTurn
                            ? 'התור שלך'
                            : 'ממתינים',
                    leading: IconButton(
                      icon: const Icon(
                        Icons.exit_to_app_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () =>
                          _confirmExit(context, currentUser.id),
                    ),
                    trailing: _ScorePill(score: myPlayer?.score ?? 0),
                  ),
                  const SizedBox(height: 4),
                  // Players strip – sizes itself from its own content
                  _PlayersStrip(
                    room: room,
                    currentUserId: currentUser.id,
                    compact: room.players.length > 5,
                  ),
                  const SizedBox(height: 6),
                  // Board – fills all remaining vertical space,
                  // board square is computed inside to never overflow.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bc) {
                        final side =
                            math.min(bc.maxWidth, bc.maxHeight).toDouble();
                        return Center(
                          child: Transform.scale(
                            scale: imageScale,
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                radius: 30,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: _ImageRevealBoard(
                                    room: room,
                                    gameImage: _gameImage,
                                    gridSize: gridSize,
                                    canFlipPiece: canFlipPiece,
                                    onFlip: (index) =>
                                        _flipPiece(index, room),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Action buttons – shown only on the active player's turn
                  if (canSubmitAnswer) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'נחש',
                      icon: Icons.psychology_alt_rounded,
                      onPressed: () => _openGuessSheet(room),
                    ),
                    // After flipping a piece the player can skip guessing –
                    // this button is prominent so it is never missed.
                    if (_hasFlipped)
                      TextButton.icon(
                        onPressed: _isActing ? null : _endTurn,
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: const Text('דלג על הניחוש'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondary,
                          textStyle: AppTextStyles.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
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
            child: const Text('הישאר'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(roomServiceProvider)
                  .leaveRoom(widget.roomId, userId);
              if (context.mounted) context.go('/home');
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            child: const Text('צא'),
          ),
        ],
      ),
    );
  }
}

class _GameBackground extends StatelessWidget {
  final double revealedRatio;

  const _GameBackground({required this.revealedRatio});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.25 + revealedRatio * 0.25),
          radius: 1.05,
          colors: const [
            Color(0xFF26358C),
            Color(0xFF11183B),
            Color(0xFF070B20),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int score;

  const _ScorePill({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        '$score',
        style: AppTextStyles.body.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PlayersStrip extends StatelessWidget {
  final RoomModel room;
  final String? currentUserId;
  final bool compact;

  const _PlayersStrip({
    required this.room,
    this.currentUserId,
    required this.compact,
  });

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
  final RoomModel room;
  final GameImageModel? gameImage;
  final int gridSize;
  final bool canFlipPiece;
  final void Function(int)? onFlip;

  const _ImageRevealBoard({
    required this.room,
    required this.gameImage,
    required this.gridSize,
    required this.canFlipPiece,
    this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (gameImage != null)
          CachedNetworkImage(
            imageUrl: gameImage!.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.boardBackground),
            errorWidget: (_, __, ___) =>
                Container(color: AppColors.boardBackground),
          )
        else
          Container(color: AppColors.boardBackground),
        GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: gridSize,
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemCount: gridSize * gridSize,
          itemBuilder: (context, index) {
            final isRevealed = room.placedPieces.containsKey(index);
            final canFlip = canFlipPiece && !isRevealed;

            if (isRevealed) {
              return const SizedBox.expand();
            }

            return GestureDetector(
              key: ValueKey('hidden_$index'),
              onTap: canFlip ? () => onFlip?.call(index) : null,
              child: _AnimatedHiddenTile(enabled: canFlip),
            );
          },
        ),
      ],
    );
  }
}

class _AnimatedHiddenTile extends StatelessWidget {
  final bool enabled;

  const _AnimatedHiddenTile({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withOpacity(0.97)
            : const Color(0xFF11183B).withOpacity(0.96),
        border: Border.all(
          color: Colors.white.withOpacity(enabled ? 0.18 : 0.08),
          width: 0.5,
        ),
      ),
      child: Center(
        child: AnimatedOpacity(
          opacity: enabled ? 0.85 : 0.25,
          duration: const Duration(milliseconds: 160),
          child: const Text(
            '?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
