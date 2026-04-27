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
    final imagesAsync = ref.watch(publicImagesProvider);

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

        return Scaffold(
          appBar: AppBar(
            title: const Text('הצבע על נושא'),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Vote counter + host badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '🗳️ בחרו נושא לפאזל',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.darkBlue,
                            ),
                          ),
                        ),
                        if (isHost)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '👑 ×2',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 20),

                  Expanded(
                    child: imagesAsync.when(
                      data: (images) {
                        const availableCategories = [
                          ImageCategory.landmark,
                          ImageCategory.israeliLandmark,
                        ];

                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: availableCategories.length,
                          itemBuilder: (context, i) {
                            final cat = availableCategories[i];
                            final isSelected =
                                _selectedCategory == cat.name;
                            final voteCount = room.imageVotes.values
                                .where((v) => v == cat.name)
                                .length;

                            return GestureDetector(
                              onTap: myVote == null
                                  ? () => setState(
                                      () => _selectedCategory = cat.name)
                                  : null,
                              child: _CategoryCard(
                                category: cat,
                                imageCount: images
                                    .where((img) => img.category == cat)
                                    .length,
                                isSelected: isSelected,
                                voteCount: voteCount,
                                isLocked: myVote != null,
                              ),
                            )
                                .animate(delay: (i * 80).ms)
                                .fadeIn()
                                .scale(curve: Curves.elasticOut);
                          },
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) =>
                          Center(child: Text('שגיאה: $e')),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (myVote == null)
                    GradientButton(
                      text: _selectedCategory != null
                          ? 'אשר בחירה'
                          : 'בחר נושא תחילה',
                      onPressed: _selectedCategory != null
                          ? () => _confirmVote(room)
                          : null,
                    ).animate(delay: 300.ms).fadeIn()
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
  final int imageCount;
  final bool isSelected;
  final int voteCount;
  final bool isLocked;

  const _CategoryCard({
    required this.category,
    required this.imageCount,
    required this.isSelected,
    required this.voteCount,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withOpacity(0.25)
                : Colors.black.withOpacity(0.06),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 44),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.darkBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$imageCount תמונות',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            const Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.check, color: Colors.white, size: 14),
              ),
            ),
          if (voteCount > 0)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🗳️ $voteCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
