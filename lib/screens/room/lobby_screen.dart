import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/game_constants.dart';
import '../../providers/providers.dart';
import '../../models/player_model.dart';
import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/player_avatar.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  // פלטת צבעים "בננו בננה"
  static const Color _navyTop = Color(0xFF07101F);
  static const Color _navyBottom = Color(0xFF0A1D3A);
  static const Color _bananaYellow = Color(0xFFFFE14D);
  static const Color _cyanGlow = Color(0xFF00F2FF);
  static const Color _glassWhite = Color(0x22FFFFFF);

  bool _isStarting = false;
  bool _codeCopied = false;

  Future<void> _copyCode(String code) async {
    if (_codeCopied) return;
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _codeCopied = false);
  }

  void _shareToWhatsApp(String code) {
    Share.share('בואו לשחק איתי בננו בננה! קוד החדר: $code');
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
          return const SizedBox();
        }

        final isHost = currentUser?.id == room.hostId;
        final hostName = room.players[room.hostId]?.name ?? 'המארח';
        final canStart = room.players.length >= GameConstants.minPlayers;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_navyTop, _navyBottom],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Column(
                      children: [
                        // Header: ברוכים הבאים
                        _buildHeader(context, currentUser, hostName),
                        
                        SizedBox(height: h * 0.03),
                        
                        // כרטיס קוד חדר Glossy
                        _GlossyRoomCode(
                          code: room.code,
                          isCopied: _codeCopied,
                          onCopy: () => _copyCode(room.code),
                          onShare: () => _shareToWhatsApp(room.code),
                        ),
                        
                        SizedBox(height: h * 0.04),
                        
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'שחקנים בסטודיו', 
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: _cyanGlow, blurRadius: 10)],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // גריד 8 שחקנים (2X4)
                        Expanded(
                          child: _PlayerGrid(
                            players: room.players.values.toList(),
                            currentUserId: currentUser?.id,
                          ),
                        ),
                        
                        // כפתור פעולה בתחתית
                        SizedBox(
                          height: 75,
                          child: isHost
                              ? _GlossyActionButton(
                                  label: _isStarting ? 'מכין צמצמים...' : 'התחל משחק',
                                  enabled: canStart && !_isStarting,
                                  onTap: () async {
                                    setState(() => _isStarting = true);
                                    try {
                                      await ref.read(roomServiceProvider).startGameDirectly(widget.roomId);
                                    } catch (e) {
                                      setState(() => _isStarting = false);
                                    }
                                  },
                                )
                              : _WaitingFooter(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _bananaYellow)),
      error: (e, _) => Center(child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white))),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic currentUser, String hostName) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        GestureDetector(
          onTap: () async {
            if (currentUser != null) {
              await ref.read(roomServiceProvider).leaveRoom(widget.roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'ברוכים הבאים לחדר של $hostName',
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Text(
              'לובי הסטודיו',
              style: TextStyle(
                color: Colors.white, 
                fontSize: 28, 
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 40), // איזון לכפתור החזרה
      ],
    );
  }
}

class _GlossyRoomCode extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _GlossyRoomCode({
    required this.code,
    required this.isCopied,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 28),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onCopy,
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                color: isCopied ? Colors.greenAccent : Colors.white54,
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text('לחץ להעתקה או שתף לחברים', 
            style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  final List<PlayerModel> players;
  final String? currentUserId;

  const _PlayerGrid({required this.players, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 15,
        mainAxisSpacing: 20,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        if (index < players.length) {
          final player = players[index];
          return _PlayerAvatarTile(
            player: player, 
            isMe: player.id == currentUserId,
          );
        }
        return _EmptyPlayerTile();
      },
    );
  }
}

class _PlayerAvatarTile extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;
  const _PlayerAvatarTile({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isMe ? const Color(0xFF00F2FF) : Colors.white30, width: 2),
            boxShadow: [
              if (isMe) BoxShadow(color: const Color(0xFF00F2FF).withOpacity(0.5), blurRadius: 10),
            ],
          ),
          child: PlayerAvatar(name: player.name, radius: 28),
        ),
        const SizedBox(height: 8),
        Text(
          isMe ? 'אני' : player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMe ? const Color(0xFF00F2FF) : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (player.isHost) const Text('👑', style: TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _EmptyPlayerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white10, width: 1),
          ),
          child: const Icon(Icons.add, color: Colors.white24, size: 24),
        ),
        const SizedBox(height: 8),
        const Text('ממתין...', style: TextStyle(color: Colors.white24, fontSize: 11)),
      ],
    );
  }
}

class _GlossyActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GlossyActionButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled 
                ? [const Color(0xFFFFE14D), const Color(0xFFFFB800)] 
                : [Colors.white10, Colors.white10],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            if (enabled) BoxShadow(color: const Color(0xFFFFB800).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
          ],
          border: Border.all(color: Colors.white30, width: 2),
        ),
        child: Center(
          child: Text(
            label, 
            style: TextStyle(
              color: enabled ? const Color(0xFF07101F) : Colors.white24, 
              fontSize: 24, 
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'ממתין למארח שיתחיל...', 
        style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
