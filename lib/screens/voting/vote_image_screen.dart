import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/game_image_model.dart';
import '../../models/room_model.dart';
import '../../widgets/common/gradient_button.dart';

class VoteImageScreen extends ConsumerStatefulWidget {
  final String roomId;

  const VoteImageScreen({super.key, required this.roomId});

  @override
  ConsumerState<VoteImageScreen> createState() => _VoteImageScreenState();
}

class _VoteImageScreenState extends ConsumerState<VoteImageScreen> {
  String? _selectedImageId;
  bool _hasVoted = false;

  void _vote(String imageId) {
    if (_hasVoted) return;
    setState(() => _selectedImageId = imageId);
  }

  Future<void> _confirmVote() async {
    if (_selectedImageId == null || _hasVoted) return;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _hasVoted = true);

    await ref.read(roomServiceProvider).castImageVote(
          roomId: widget.roomId,
          userId: user.id,
          imageId: _selectedImageId!,
        );

    // If host, check if all voted
    final room = ref.read(currentRoomProvider).value;
    if (room != null && user.id == room.hostId) {
      if (room.imageVotes.length + 1 >= room.players.length) {
        await ref
            .read(roomServiceProvider)
            .resolveImageVote(widget.roomId, user.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomProvider);
    final imagesAsync = ref.watch(publicImagesProvider);

    return roomAsync.when(
      data: (room) {
        if (room == null) return const SizedBox();

        // Navigate to difficulty voting
        if (room.phase == GamePhase.votingDifficulty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/vote-difficulty/${widget.roomId}');
          });
        }

        final currentUser = ref.read(currentUserProvider).value;
        final isHost = currentUser?.id == room.hostId;
        final allVoted = room.imageVotes.length >= room.players.length;
        final myVote = room.imageVotes[currentUser?.id];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vote for Image'),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Vote progress
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🗳️ Vote for the image to reveal!',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkBlue,
                          ),
                        ),
                        Text(
                          '${room.imageVotes.length}/${room.players.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),

                  const SizedBox(height: 16),

                  // Host vote weight info
                  if (isHost)
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
                            'Your vote counts as 2 points!',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 200.ms).fadeIn(),

                  const SizedBox(height: 16),

                  Expanded(
                    child: imagesAsync.when(
                      data: (images) {
                        final displayImages = images.take(6).toList();
                        return GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: displayImages.length,
                          itemBuilder: (context, i) {
                            final img = displayImages[i];
                            final isSelected = _selectedImageId == img.id;
                            final hasVotedFor = room.imageVotes.values
                                .where((v) => v == img.id)
                                .length;

                            return GestureDetector(
                              onTap: myVote == null ? () => _vote(img.id) : null,
                              child: _ImageCard(
                                image: img,
                                isSelected: isSelected,
                                voteCount: hasVotedFor,
                                isLocked: myVote != null,
                              ),
                            )
                                .animate(delay: (i * 100).ms)
                                .fadeIn()
                                .scale(curve: Curves.elasticOut);
                          },
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (myVote == null)
                    GradientButton(
                      text: _selectedImageId != null
                          ? 'Confirm Vote'
                          : 'Select an image first',
                      onPressed: _selectedImageId != null ? _confirmVote : null,
                    ).animate(delay: 400.ms).fadeIn()
                  else if (isHost && allVoted)
                    GradientButton(
                      text: 'Reveal Result & Continue',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => ref
                          .read(roomServiceProvider)
                          .resolveImageVote(widget.roomId, currentUser!.id),
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
                            'Vote submitted! Waiting for others...',
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
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ImageCard extends StatelessWidget {
  final GameImageModel image;
  final bool isSelected;
  final int voteCount;
  final bool isLocked;

  const _ImageCard({
    required this.image,
    required this.isSelected,
    required this.voteCount,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: image.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.boardBackground,
                child: const Center(
                  child: Icon(Icons.image_rounded,
                      color: AppColors.pieceSlotEmpty, size: 40),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.boardBackground,
                child: Center(
                  child: Text(
                    image.category.label,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            // Blur overlay for category
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      image.category.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (voteCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
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
          ],
        ),
      ),
    );
  }
}
