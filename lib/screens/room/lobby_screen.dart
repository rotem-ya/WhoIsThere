import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../models/player_model.dart';
import '../../widgets/common/gradient_button.dart';
import '../../widgets/common/player_avatar.dart';

class LobbyScreen extends ConsumerWidget {
  final String roomId;

  const LobbyScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(currentRoomProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
          return const SizedBox();
        }

        if (room.phase == GamePhase.votingImage) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/vote-image/$roomId');
          });
        }

        final isHost = currentUser?.id == room.hostId;
        final canStart = room.players.length >= GameConstants.minPlayers;

        return Scaffold(
          appBar: AppBar(
            title: const Text('לובי'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                if (currentUser != null) {
                  await ref
                      .read(roomServiceProvider)
                      .leaveRoom(roomId, currentUser.id);
                }
                if (context.mounted) context.go('/home');
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'קוד חדר',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            room.code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'שחקנים (${room.players.length}/${GameConstants.maxPlayers})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkBlue,
                        ),
                      ),
                      if (!canStart)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'חסרים עוד ${GameConstants.minPlayers - room.players.length}',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: room.players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final player =
                            room.players.values.elementAt(index);
                        return _PlayerTile(
                          player: player,
                          isCurrentUser: player.id == currentUser?.id,
                        )
                            .animate(delay: (index * 100).ms)
                            .fadeIn()
                            .slideX(begin: -0.2);
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (isHost)
                    GradientButton(
                      text: canStart ? 'התחל משחק' : 'ממתין לשחקנים...',
                      icon: Icons.play_arrow_rounded,
                      onPressed: canStart
                          ? () => ref
                              .read(roomServiceProvider)
                              .startVotingImage(roomId)
                          : null,
                    ).animate(delay: 300.ms).fadeIn()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty_rounded,
                              color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'ממתין למארח להתחיל...',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 300.ms).fadeIn(),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('שגיאה: $e')),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final PlayerModel player;
  final bool isCurrentUser;

  const _PlayerTile({required this.player, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary.withOpacity(0.3)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          PlayerAvatar(
            name: player.name,
            photoUrl: player.photoUrl,
            radius: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.name + (isCurrentUser ? ' (את/ה)' : player.isBot ? ' 🎮' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.darkBlue,
              ),
            ),
          ),
          if (player.isHost)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '👑 מארח',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
