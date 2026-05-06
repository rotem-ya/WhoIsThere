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
  static const Color _goldDark = Color(0xFFA1811A);
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
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -80,
                  child: _GlowCircle(color: _gold.withOpacity(0.12), size: 280),
                ),
                Positioned(
                  bottom: 120,
                  left: -100,
                  child: _GlowCircle(color: _cyan.withOpacity(0.12), size: 260),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        _LobbyHeader(
                          onExit: () async {
                            AppFeedback.tap();
                            if (currentUser != null) {
                              await ref
                                  .read(roomServiceProvider)
                                  .leaveRoom(widget.roomId, currentUser.id);
                            }
                            if (context.mounted) context.go('/home');
                          },
                        ),
                        const SizedBox(height: 18),
                        _RoomCodeCard(
                          code: room.code,
                          isCopied: _codeCopied,
                          onTap: () => _copyCode(room.code),
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'שחקנים (${room.players.length}/${GameConstants.maxPlayers})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final tileHeight =
                                  (constraints.maxHeight / 4).clamp(58.0, 76.0);
                              return GridView.builder(
                                itemCount: room.players.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: AppSpacing.sm,
                                  crossAxisSpacing: AppSpacing.sm,
                                  mainAxisExtent: tileHeight,
                                ),
                                itemBuilder: (context, index) {
                                  final player = room.players.values.elementAt(index);
                                  return _PlayerTile(
                                    player: player,
                                    isCurrentUser: player.id == currentUser?.id,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isHost)
                          _GoldStartButton(
                            pulseController: _pulseController,
                            label: _isStarting
                                ? 'מתחיל...'
                                : canStart
                                    ? 'התחל משחק'
                                    : 'ממתין לשחקנים',
                            enabled: canStart && !_isStarting,
                            onTap: _startGame,
                          )
                        else
                          _WaitingCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: _navyTop,
        body: Center(child: CircularProgressIndicator(color: _gold)),
      ),
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
        _IconButtonFrame(
          icon: Icons.logout_rounded,
          onTap: onExit,
        ),
        const Expanded(
          child: Column(
            children: [
              _MiniVaultIcon(),
              SizedBox(height: 10),
              Text(
                'לובי',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Color(0xFFD4AF37), blurRadius: 16),
                    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 56),
      ],
    );
  }
}

class _MiniVaultIcon extends StatelessWidget {
  const _MiniVaultIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: _LobbyScreenState._navyCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _LobbyScreenState._gold, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: _LobbyScreenState._cyan.withOpacity(0.35),
            blurRadius: 22,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              if (index == 4) return const SizedBox.shrink();
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF050A14),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: index.isEven
                        ? _LobbyScreenState._gold.withOpacity(0.45)
                        : _LobbyScreenState._cyan.withOpacity(0.45),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _LobbyScreenState._cyan.withOpacity(0.92),
              boxShadow: [
                BoxShadow(
                  color: _LobbyScreenState._cyan.withOpacity(0.65),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onTap;

  const _RoomCodeCard({
    required this.code,
    required this.isCopied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isCopied ? _LobbyScreenState._cyan : Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            if (isCopied)
              BoxShadow(
                color: _LobbyScreenState._cyan.withOpacity(0.45),
                blurRadius: 28,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Column(
          children: [
            Text(
              isCopied ? 'הקוד הועתק ✓' : 'קוד חדר – לחץ להעתקה',
              style: const TextStyle(
                color: Color(0xFF5E667A),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code,
                textDirection: TextDirection.ltr,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF101936),
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFFA1811A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive ? null : Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? _LobbyScreenState._gold.withOpacity(0.9)
              : _LobbyScreenState._cyan.withOpacity(0.38),
          width: 1.5,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: _LobbyScreenState._gold.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          PlayerAvatar(
            name: player.name,
            photoUrl: player.photoUrl,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name + (player.isBot ? ' 🎮' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isActive ? const Color(0xFF07101F) : Colors.white,
              ),
            ),
          ),
          if (player.isHost) const Text('👑', style: TextStyle(fontSize: 20)),
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

  const _GoldStartButton({
    required this.pulseController,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: enabled ? 1.025 : 1.0).animate(
        CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
      ),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1.0 : 0.52,
          child: Container(
            height: 76,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE27A), Color(0xFFD4AF37), Color(0xFFA1811A)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _LobbyScreenState._gold.withOpacity(enabled ? 0.45 : 0.0),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, color: Color(0xFF07101F), size: 38),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF07101F),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _LobbyScreenState._cyan.withOpacity(0.35)),
      ),
      child: const Text(
        'ממתין למארח להתחיל...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
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
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 42)],
      ),
    );
  }
}
