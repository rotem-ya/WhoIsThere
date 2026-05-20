import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/game_constants.dart';
import '../../core/theme/app_styles.dart';
import '../../providers/providers.dart';
import '../../models/player_model.dart';
import '../../services/qa_logger_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/common/app_feedback.dart';
import '../../widgets/common/player_avatar.dart';
import '../../widgets/common/pressable_scale.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LobbyScreen({super.key, required this.roomId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isStarting = false;
  bool _codeCopied = false;
  bool _lobbyLogged = false;

  @override
  void initState() {
    super.initState();
    QaLoggerService.instance.log('LOBBY', 'LOBBY_SCREEN_OPENED roomId=${widget.roomId.substring(0, widget.roomId.length.clamp(0, 6))}');
  }

  Future<void> _copyCode(String code) async {
    if (_codeCopied) return;
    QaLoggerService.instance.log('LOBBY', 'COPY_ROOM_CODE_TAPPED code=$code');
    AppFeedback.success();
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _codeCopied = false);
  }

  void _shareToWhatsApp(String code) {
    QaLoggerService.instance.log('LOBBY', 'SHARE_ROOM_TAPPED code=$code');
    final msg = StringBuffer();
    msg.writeln('בואו לגלות מה בתמונה 📸');
    msg.writeln();
    msg.writeln('קוד חדר: $code');
    msg.writeln();
    msg.writeln('🎮 הצטרפות ישירה לחדר:');
    msg.write('https://rotem-ya.github.io/apps-share-pages/whoisthere/join?code=$code');
    Share.share(msg.toString());
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

        if (!_lobbyLogged) {
          _lobbyLogged = true;
          QaLoggerService.instance.log(
              'LOBBY', 'LOBBY_ROOM_DATA code=${room.code} players=${room.players.length}');
        }

        if (room.phase == GamePhase.playing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/game/${room.id}');
          });
          return const SizedBox.shrink();
        }

        final isHost = currentUser?.id == room.hostId;
        final rawHostName = room.players[room.hostId]?.name ?? '';
        final hostName = rawHostName.isEmpty ? 'המארח' : rawHostName;
        final canStart = room.players.length >= GameConstants.minPlayers;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppStyles.backgroundGradient,
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Header ──────────────────────────────────────
                            _buildHeader(context, currentUser, hostName),

                            const SizedBox(height: 12),

                            // ── Room Code Card ───────────────────────────────
                            _GlossyRoomCode(
                              code: room.code,
                              isCopied: _codeCopied,
                              onCopy: () => _copyCode(room.code),
                              onShare: () => _shareToWhatsApp(room.code),
                            ),

                            const SizedBox(height: 12),

                            // ── Section label ─────────────────────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'שחקנים בסטודיו',
                                style: AppStyles.heading3.copyWith(
                                  shadows: [
                                    Shadow(
                                      color: AppStyles.cyanGlow.withOpacity(0.8),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // ── Players grid (2 × 4 = 8 fixed slots) ──────────
                            _PlayerGrid(
                              players: room.players.values.toList(),
                              currentUserId: currentUser?.id,
                            ),

                            const SizedBox(height: 8),

                            // ── Min-players hint (host only, when not enough players) ──
                            if (isHost && !canStart) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'צריך לפחות 2 שחקנים כדי להתחיל',
                                  textAlign: TextAlign.center,
                                  style: AppStyles.bodySmall.copyWith(
                                    color: const Color(0xFFFFE082).withOpacity(0.85),
                                  ),
                                ),
                              ),
                            ],

                            // ── Action button / waiting footer ─────────────────
                            SizedBox(
                              height: 52,
                              width: double.infinity,
                              child: isHost
                                  ? GestureDetector(
                                      onTap: !canStart
                                          ? () => QaLoggerService.instance.log(
                                              'LOBBY', 'START_GAME_BLOCKED_MIN_PLAYERS players=${room.players.length}')
                                          : null,
                                      child: _GlossyActionButton(
                                      label: _isStarting ? 'מכין צמצמים...' : 'התחל משחק',
                                      enabled: canStart && !_isStarting,
                                      onTap: () async {
                                        debugPrint('Lobby start tapped: roomId=${widget.roomId}');
                                        setState(() => _isStarting = true);
                                        try {
                                          await ref
                                              .read(roomServiceProvider)
                                              .startGameDirectly(widget.roomId);
                                          debugPrint('Lobby start success');
                                        } catch (e) {
                                          debugPrint('Lobby startGameDirectly error: $e');
                                          if (mounted) {
                                            setState(() => _isStarting = false);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('לא ניתן להתחיל משחק: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    )
                                  : const _WaitingFooter(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: Center(
          child: CircularProgressIndicator(color: AppStyles.bananaYellow),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppStyles.navyTop,
        body: Center(
          child: Text('שגיאה: $e', style: AppStyles.bodyLarge),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic currentUser, String hostName) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        // Back / leave button
        GestureDetector(
          onTap: () async {
            if (currentUser != null) {
              await ref
                  .read(roomServiceProvider)
                  .leaveRoom(widget.roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38),
              boxShadow: AppStyles.cyanGlowShadow(intensity: 0.3),
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Title block — Expanded gives maximum available width
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ברוכים הבאים לחדר של $hostName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppStyles.bodySmall.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                'לובי הסטודיו',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppStyles.heading1.copyWith(fontSize: 22),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),
        const SizedBox(width: 36),
      ],
    );
  }
}

// ── Room Code Card ─────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppStyles.glassCard(radius: 24, opacity: 0.20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // WhatsApp share
                PressableScale(
                  onTap: onShare,
                  scale: 0.88,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.share_rounded,
                      color: Color(0xFF25D366),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Room code — tap to copy
                GestureDetector(
                  onTap: onCopy,
                  child: Text(
                    code,
                    style: AppStyles.cyanLabelLarge.copyWith(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                      shadows: AppStyles.cyanGlowShadow(intensity: 0.6)
                          .map((s) => Shadow(
                                color: s.color,
                                blurRadius: s.blurRadius,
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Copy status icon
                Icon(
                  isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                  color: isCopied ? Colors.greenAccent : Colors.white54,
                  size: 22,
                ),
              ],
            ),
          ),
          Text(
            'לחץ להעתקה או שתף לחברים',
            style: AppStyles.bodySmall.copyWith(color: Colors.white54),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms, curve: Curves.easeOut)
        .scaleXY(begin: 0.94, end: 1.0, duration: 350.ms, curve: Curves.easeOut);
  }
}

// ── Players Grid (fixed 2 × 4 = 8 slots) ──────────────────────────────────

class _PlayerGrid extends StatelessWidget {
  final List<PlayerModel> players;
  final String? currentUserId;

  const _PlayerGrid({required this.players, this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 8,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (context, index) {
        if (index < players.length) {
          return _PlayerAvatarTile(
            player: players[index],
            isMe: players[index].id == currentUserId,
            delay: Duration(milliseconds: 120 + index * 55),
          );
        }
        return const _EmptyPlayerTile();
      },
    );
  }
}

// ── Filled player slot ─────────────────────────────────────────────────────

class _PlayerAvatarTile extends StatelessWidget {
  final PlayerModel player;
  final bool isMe;
  final Duration delay;

  const _PlayerAvatarTile({
    required this.player,
    required this.isMe,
    this.delay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final base = isMe ? 'אני' : (player.name.isNotEmpty ? player.name : 'שחקן');
    final label = player.isHost ? '$base 👑' : base;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppStyles.glassCard(radius: 16, opacity: 0.18).copyWith(
        boxShadow: isMe ? AppStyles.cyanGlowShadow(intensity: 0.7) : null,
        border: Border.all(
          color: isMe
              ? AppStyles.cyanGlow.withOpacity(0.7)
              : Colors.white.withOpacity(0.20),
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Avatar with cyan ring for current user
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isMe ? AppStyles.cyanGlow : Colors.white38,
                width: 2,
              ),
              boxShadow: isMe ? AppStyles.cyanGlowShadow(intensity: 0.5) : null,
            ),
            child: PlayerAvatar(name: player.name, radius: 14),
          ),
          const SizedBox(width: 8),

          // Single-line name (crown inline for host)
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppStyles.bodyMedium.copyWith(
                color: isMe ? AppStyles.cyanGlow : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: 280.ms, curve: Curves.easeOut)
        .slideX(begin: -0.06, end: 0, delay: delay, duration: 280.ms, curve: Curves.easeOut);
  }
}

// ── Empty waiting slot ─────────────────────────────────────────────────────

class _EmptyPlayerTile extends StatelessWidget {
  const _EmptyPlayerTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white12, width: 1.5),
            ),
            child: const Icon(Icons.add, color: Colors.white24, size: 20),
          ),
          const SizedBox(width: 10),
          SoftPulse(
            minOpacity: 0.35,
            maxOpacity: 0.70,
            child: Text(
              'ממתין...',
              style: AppStyles.bodySmall.copyWith(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Start game button (host only) ──────────────────────────────────────────

class _GlossyActionButton extends StatefulWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GlossyActionButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_GlossyActionButton> createState() => _GlossyActionButtonState();
}

class _GlossyActionButtonState extends State<_GlossyActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed && widget.enabled ? 0.97 : 1.0,
      duration: _pressed
          ? const Duration(milliseconds: 90)
          : const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onHighlightChanged:
              widget.enabled ? (h) => setState(() => _pressed = h) : null,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            decoration: widget.enabled
                ? AppStyles.glossyButton(radius: 20)
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white10,
                    border: Border.all(color: Colors.white12),
                  ),
            child: Center(
              child: Text(
                widget.label,
                style: AppStyles.labelButton.copyWith(
                  fontSize: 20,
                  color: widget.enabled ? AppStyles.darkText : Colors.white24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Non-host waiting message ───────────────────────────────────────────────

class _WaitingFooter extends StatelessWidget {
  const _WaitingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: AppStyles.glassCard(radius: 20, opacity: 0.10),
      child: SoftPulse(
        minOpacity: 0.50,
        maxOpacity: 1.0,
        child: Text(
          'ממתין למארח שיתחיל...',
          style: AppStyles.bodyMedium.copyWith(color: Colors.white54),
        ),
      ),
    );
  }
}
