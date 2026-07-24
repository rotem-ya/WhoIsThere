import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/candy_theme.dart';
import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../core/ui/app_scaffold.dart';
import '../../core/ui/app_spacing.dart';
import '../../core/ui/app_text_styles.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/branded_loader.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_header.dart';

class VoteDifficultyScreen extends ConsumerStatefulWidget {
  final String roomId;

  const VoteDifficultyScreen({super.key, required this.roomId});

  @override
  ConsumerState<VoteDifficultyScreen> createState() =>
      _VoteDifficultyScreenState();
}

class _VoteDifficultyScreenState extends ConsumerState<VoteDifficultyScreen> {
  Difficulty? _selected;
  bool _hasVoted = false;

  Future<void> _confirmVote(RoomModel room) async {
    if (_selected == null || _hasVoted) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _hasVoted = true);

    try {
      await ref.read(roomServiceProvider).castDifficultyVote(
            roomId: widget.roomId,
            userId: user.id,
            difficulty: _selected!,
          );

      final virtualPlayers = room.players.values.where((p) => p.isBot);
      for (final player in virtualPlayers) {
        final randomDifficulty =
            Difficulty.values[Random().nextInt(Difficulty.values.length)];
        await ref.read(roomServiceProvider).castDifficultyVote(
              roomId: widget.roomId,
              userId: player.id,
              difficulty: randomDifficulty,
            );
      }

      if (mounted) {
        await ref
            .read(roomServiceProvider)
            .resolveDifficultyVote(widget.roomId, user.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasVoted = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בהצבעה: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        if (room.phase == GamePhase.playing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        if (currentUser == null) return const SizedBox();
        final isHost = currentUser.id == room.hostId;
        final allVoted = room.difficultyVotes.length >= room.players.length;
        final myVote = room.difficultyVotes[currentUser.id];
        const choices = [Difficulty.easy, Difficulty.medium, Difficulty.hard];

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) async {
            if (didPop) return;
            // Mirror the exit button: leave the room on Android back so the
            // player isn't left behind as a ghost in the room document.
            await ref
                .read(roomServiceProvider)
                .leaveRoom(widget.roomId, currentUser.id);
            if (context.mounted) context.go('/home');
          },
          child: AppScaffold(
          backgroundGradient: AppStyles.backgroundGradient,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              AppHeader(
                title: 'רמת קושי',
                leading: IconButton(
                  icon: const Icon(Icons.exit_to_app_rounded,
                      color: Colors.white),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(roomServiceProvider)
                        .leaveRoom(widget.roomId, currentUser.id);
                    if (context.mounted) context.go('/home');
                  },
                ),
              ),
              Text(
                isHost ? 'הצבעת המארח שווה פי 2' : 'בחרו כמה צפוף יהיה הגריד',
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitleLight,
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: choices.map((difficulty) {
                    final selected = _selected == difficulty;
                    final votes = room.difficultyVotes.values
                        .where((v) => v == difficulty.pieces)
                        .length;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _DifficultyCard(
                          difficulty: difficulty,
                          selected: selected,
                          votes: votes,
                          onTap: myVote == null
                              ? () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _selected = difficulty);
                                }
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (myVote == null)
                AppButton(
                  label: _selected == null ? 'בחר קושי' : 'אשר קושי',
                  icon: Icons.grid_view_rounded,
                  onPressed:
                      _selected != null ? () => _confirmVote(room) : null,
                )
              else if (isHost && allVoted)
                AppButton(
                  label: 'התחל את הפאזל',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => ref
                      .read(roomServiceProvider)
                      .resolveDifficultyVote(widget.roomId, currentUser.id),
                )
              else
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'הצבעה נשלחה. מחכים לכולם...',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                ),
            ],
          ),
        ), // AppScaffold
        ); // PopScope
      },
      loading: () => const BrandedLoader(),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final Difficulty difficulty;
  final bool selected;
  final int votes;
  final VoidCallback? onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.selected,
    required this.votes,
    required this.onTap,
  });

  int get gridSize {
    switch (difficulty) {
      case Difficulty.easy:
        return 5;
      case Difficulty.medium:
        return 7;
      case Difficulty.hard:
        return 9;
      case Difficulty.veryEasy:
        return 5;
      case Difficulty.giant:
        return 10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight;
        // Reduce emoji and padding on compact cards so 3 cards fit on small screens.
        final isCompact = cardHeight < 110;
        final emojiSize = isCompact ? 28.0 : 42.0;
        final EdgeInsets padding = isCompact
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm)
            : const EdgeInsets.all(AppSpacing.lg);
        final gap = isCompact ? AppSpacing.sm : AppSpacing.lg;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            height: cardHeight,
            padding: padding,
            decoration: BoxDecoration(
              color: selected ? Candy.gold : Candy.ink,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(selected ? 0.24 : 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(difficulty.emoji,
                    style: TextStyle(fontSize: emojiSize)),
                SizedBox(width: gap),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        difficulty.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: selected
                            ? AppTextStyles.titleLight
                            : AppTextStyles.titleDark,
                      ),
                      if (!isCompact) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$gridSize×$gridSize • ${difficulty.startingPoints} נקודות פתיחה',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: selected
                              ? AppTextStyles.subtitleLight
                              : AppTextStyles.subtitleDark,
                        ),
                      ],
                      if (votes > 0 && !isCompact)
                        Text(
                          '$votes הצבעות',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: selected
                              ? AppTextStyles.subtitleLight
                              : AppTextStyles.subtitleDark,
                        ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 28),
              ],
            ),
          ),
        );
      },
    );
  }
}
