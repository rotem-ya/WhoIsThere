import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../widgets/common/gradient_button.dart';

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
    final roomAsync = ref.watch(currentRoomProvider);
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('בחר רמת קושי'),
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              onPressed: () async {
                await ref
                    .read(roomServiceProvider)
                    .leaveRoom(widget.roomId, currentUser.id);
                if (context.mounted) context.go('/home');
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🎯 כמה קשה יהיה?',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        Text(
                          '${room.difficultyVotes.length}/${room.players.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.secondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),

                  if (isHost) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('👑', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'הצבעתך שווה 2!',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fadeIn(),
                  ],

                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView(
                      children: Difficulty.values
                          .asMap()
                          .entries
                          .map(
                            (entry) => _DifficultyCard(
                              difficulty: entry.value,
                              isSelected: _selected == entry.value,
                              isLocked: myVote != null,
                              voteCount: room.difficultyVotes.values
                                  .where((v) => v == entry.value.pieces)
                                  .length,
                              onTap: myVote == null
                                  ? () => setState(
                                      () => _selected = entry.value)
                                  : null,
                            )
                                .animate(
                                    delay: (entry.key * 100).ms)
                                .fadeIn()
                                .slideX(begin: 0.2),
                          )
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (myVote == null)
                    GradientButton(
                      text: _selected != null
                          ? 'אשר רמת קושי'
                          : 'בחר רמת קושי תחילה',
                      gradient: AppColors.secondaryGradient,
                      onPressed: _selected != null ? () => _confirmVote(room) : null,
                    ).animate(delay: 400.ms).fadeIn()
                  else if (isHost && allVoted)
                    GradientButton(
                      text: 'התחל את הפאזל!',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => ref
                          .read(roomServiceProvider)
                          .resolveDifficultyVote(
                              widget.roomId, currentUser!.id),
                    ).animate().fadeIn()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.accent),
                          SizedBox(width: 8),
                          Text(
                            'הצבעה נשלחה! ממתין...',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final Difficulty difficulty;
  final bool isSelected;
  final bool isLocked;
  final int voteCount;
  final VoidCallback? onTap;

  const _DifficultyCard({
    required this.difficulty,
    required this.isSelected,
    required this.isLocked,
    required this.voteCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.06),
                blurRadius: isSelected ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                difficulty.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      difficulty.label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${difficulty.pieces} חתיכות  •  +${difficulty.placePiecePoints}נק׳/חתיכה  •  ניצחון: +${difficulty.winReward}נק׳',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (voteCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🗳️ $voteCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
