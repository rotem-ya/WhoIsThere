import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/room_model.dart';
import '../../widgets/common/gradient_button.dart';

class VoteImageScreen extends ConsumerStatefulWidget {
  final String roomId;

  const VoteImageScreen({super.key, required this.roomId});

  @override
  ConsumerState<VoteImageScreen> createState() => _VoteImageScreenState();
}

class _VoteImageScreenState extends ConsumerState<VoteImageScreen> {
  String? _selectedCategory;
  bool _hasVoted = false;

  Future<void> _confirmVote(RoomModel room) async {
    if (_selectedCategory == null || _hasVoted) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _hasVoted = true);

    try {
      await ref.read(roomServiceProvider).castImageVote(
            roomId: widget.roomId,
            userId: user.id,
            categoryName: _selectedCategory!,
          );

      final virtualPlayers = room.players.values.where((p) => p.isBot);
      for (final player in virtualPlayers) {
        await ref.read(roomServiceProvider).castImageVote(
              roomId: widget.roomId,
              userId: player.id,
              categoryName: _selectedCategory!,
            );
      }

      if (mounted) {
        await ref
            .read(roomServiceProvider)
            .resolveImageVote(widget.roomId, user.id);
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

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        if (room.phase == GamePhase.votingDifficulty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/vote-difficulty/${widget.roomId}');
          });
        }

        final currentUser = ref.read(currentUserProvider).value;
        if (currentUser == null) return const SizedBox();
        final isHost = currentUser.id == room.hostId;
        final myVote = room.imageVotes[currentUser.id];

        const availableCategories = [
          ImageCategory.israeliLandmark,
          ImageCategory.landmark,
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FF),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'הצבע על נושא',
              style: TextStyle(
                color: AppColors.darkBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.exit_to_app_rounded, color: AppColors.darkBlue),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Header pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '🗳️',
                          style: TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'בחרו נושא לפאזל',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkBlue,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '👑 ×2',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 16),

                  // Category cards — Row+Expanded avoids aspect ratio overflow
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: availableCategories
                          .asMap()
                          .entries
                          .expand<Widget>((entry) {
                        final i = entry.key;
                        final cat = entry.value;
                        final isSelected = _selectedCategory == cat.name;
                        final voteCount = room.imageVotes.values
                            .where((v) => v == cat.name)
                            .length;

                        return [
                          Expanded(
                            child: GestureDetector(
                              onTap: myVote == null
                                  ? () => setState(
                                      () => _selectedCategory = cat.name)
                                  : null,
                              child: _CategoryCard(
                                category: cat,
                                isSelected: isSelected,
                                voteCount: voteCount,
                                isLocked: myVote != null,
                              ),
                            )
                                .animate(delay: (i * 80).ms)
                                .fadeIn(duration: 350.ms)
                                .scale(
                                  begin: const Offset(0.92, 0.92),
                                  curve: Curves.easeOutBack,
                                  duration: 400.ms,
                                ),
                          ),
                          if (i < availableCategories.length - 1)
                            const SizedBox(width: 12),
                        ];
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (myVote == null)
                    GradientButton(
                      text: _selectedCategory != null
                          ? 'אשר בחירה'
                          : 'בחר נושא תחילה',
                      onPressed: _selectedCategory != null && !_hasVoted
                          ? () => _confirmVote(room)
                          : null,
                    ).animate(delay: 200.ms).fadeIn()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.accent),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'הצבעה נשלחה! עובר לשלב הבא...',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
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

class _CategoryCard extends StatelessWidget {
  final ImageCategory category;
  final bool isSelected;
  final int voteCount;
  final bool isLocked;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.voteCount,
    required this.isLocked,
  });

  LinearGradient get _gradient {
    if (category == ImageCategory.israeliLandmark) {
      return const LinearGradient(
        colors: [Color(0xFF0057B7), Color(0xFF003580)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return AppColors.primaryGradient;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        gradient: isSelected ? _gradient : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? _gradient.colors.first.withOpacity(0.35)
                : Colors.black.withOpacity(0.06),
            blurRadius: isSelected ? 20 : 8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Emoji container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.18)
                          : AppColors.primary.withOpacity(0.07),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 42),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.darkBlue,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (voteCount > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : AppColors.secondary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '🗳️  $voteCount',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
