import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/game_constants.dart';
import '../../core/ui/app_spacing.dart';
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

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {
  static const Color _navyTop = Color(0xFF07101F);
  static const Color _navyBottom = Color(0xFF151052);
  static const Color _navyCard = Color(0xFF0A1324);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cyan = Color(0xFF87CEEB);

  bool _isStarting = false;
  bool _codeCopied = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _copyCode(String code) async {
    if (_codeCopied) return;
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _codeCopied = false);
  }

  Future<void> _startGame() async {
    if (_isStarting) return;
    AppFeedback.success();
    setState(() => _isStarting = true);
    try {
      await ref.read(roomServiceProvider).startGameDirectly(widget.roomId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בהתחלת משחק: $e')),
        );
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));
    final currentUser = ref.watch(currentUserProvider).value;

    return roomAsync.when(
      data: (room) {
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/home');
          });
          return const SizedBox();
        }

        if (room.phase == GamePhase.playing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        final isHost = currentUser?.id == room.hostId;
        final canStart = room.players.length >= GameConstants.minPlayers;

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_navyTop, Color(0xFF102B5E), _navyBottom],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    _LobbyHeader(
                      onExit: () async {
                        AppFeedback.tap();
                        if (currentUser != null) {
                          await ref.read(roomServiceProvider).leaveRoom(widget.roomId, currentUser.id);
                        }
                        if (context.mounted) context.go('/home');
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // כרטיס הקוד - גמיש למניעת באגים
                    Flexible(
                      flex: 2,
                      child: _RoomCodeCard(
                        code: room.code,
                        isCopied: _codeCopied,
                        onTap: () => _copyCode(room.code),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'שחקנים (${room.players.length}/${GameConstants.maxPlayers})',
                        style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // רשימת שחקנים שתופסת את שאר המסך
                    Expanded(
                      flex: 5,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: room.players.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 54,
                        ),
                        itemBuilder: (context, index) {
                          final player = room.players.values.elementAt(index);
                          return _PlayerTile(
                            player: player,
                            isCurrentUser: player.id == currentUser?.id,
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // כפתור הפעלה קבוע בתחתית
                    SizedBox(
                      height: 68,
                      child: isHost
                          ? _GoldStartButton(
                              pulseController: _pulseController,
                              label: _isStarting ? 'מתחיל...' : canStart ? 'התחל משחק' : 'ממתין לשחקנים',
                              enabled: canStart && !_isStarting,
                              onTap: _startGame,
                            )
                          : _WaitingCard(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(backgroundColor: _navyTop, body: Center(child: CircularProgressIndicator(color: _gold))),
      error: (e, _) => Scaffold(body: Center(child: Text('שגיאה: $e'))),
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  final Future<void> Function() onExit;
  const _LobbyHeader({required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        _IconButtonFrame(icon: Icons.logout_rounded, onTap: onExit),
        const Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('לובי', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onTap;
  const _RoomCodeCard({super.key, required this.code, required this.isCopied, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isCopied ? 'הועתק!' : 'לחץ להעתקה', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(code, style: const TextStyle(color: Color(0xFF101936), fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
            ),
          ],
        ),
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
    final isActive = isCurrentUser || player.isHost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          PlayerAvatar(name: player.name, radius: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isActive ? Colors.black : Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldStartButton extends StatelessWidget {
  final AnimationController pulseController;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _GoldStartButton({required this.pulseController, required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled 
              ? [const Color(0xFFFFE27A), const Color(0xFFD4AF37)] 
              : [Colors.grey, Colors.grey.shade700],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(label, style: const TextStyle(color: Color(0xFF07101F), fontSize: 24, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _IconButtonFrame extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onTap;
  const _IconButtonFrame({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
      child: const Text('ממתין למארח...', style: TextStyle(color: Colors.white, fontSize: 18)),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
