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
import '../../widgets/common/premium_scaffold.dart';

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

        return PremiumScaffold(
          showBeams: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              children: [
                ArcadeHeader(
                  eyebrow: 'שלב 2 מתוך 2',
                  title: 'בחרו קושי',
                  subtitle: 'יותר קשה = יותר נקודות',
                  trailing: IconButton(
                    icon: const Icon(Icons.exit_to_app_rounded,
                        color: Colors.white),
                    onPressed: () async {
                      await ref
                          .read(roomServiceProvider)
                          .leaveRoom(widget.roomId, currentUser.id);
                      if (context.mounted) context.go('/home');
                    },
                  ),
                ),
                const SizedBox(height: 16),
                PremiumGlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  radius: 22,
                  child: Row(
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'כמה חתיכות יסתירו את התמונה?',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      StatusPill(
                        text:
                            '${room.difficultyVotes.length}/${room.players.length}',
                        icon: Icons.how_to_vote_rounded,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
                if (isHost) ...[
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: StatusPill(
                      text: 'הצבעת מארח ×2',
                      icon: Icons.workspace_premium_rounded,
                      color: AppColors.warning,
                    ),
                  ).animate(delay: 100.ms).fadeIn(),
                ],
                const SizedBox(height: 16),
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
                                ? () => setState(() => _selected = entry.value)
                                : null,
                          )
                              .animate(delay: (entry.key * 80).ms)
                              .fadeIn()
                              .slideX(begin: 0.2),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (myVote == null)
                  GradientButton(
                    text:
                        _selected != null ? 'נעול קושי' : 'בחר רמת קושי תחילה',
                    gradient: AppColors.secondaryGradient,
                    onPressed:
                        _selected != null ? () => _confirmVote(room) : null,
                  ).animate(delay: 400.ms).fadeIn()
                else if (isHost && allVoted)
                  GradientButton(
                    text: 'התחל את הפאזל!',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () => ref
                        .read(roomServiceProvider)
                        .resolveDifficultyVote(widget.roomId, currentUser.id),
                  ).animate().fadeIn()
                else
                  const PremiumGlassCard(
                    padding: EdgeInsets.all(16),
                    radius: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.accent),
                        SizedBox(width: 8),
                        Text(
                          'הצבעה נשלחה. מחכים לכולם...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
              ],
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
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
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
              AnimatedScale(
                scale: isSelected ? 1.18 : 1,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Text(
                  difficulty.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
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
                        color:
                            isSelected ? AppColors.primary : AppColors.darkBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${difficulty.pieces} חתיכות  •  +${difficulty.placePiecePoints}נק׳/חתיכה\nניצחון: +${difficulty.winReward}נק׳',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (voteCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
