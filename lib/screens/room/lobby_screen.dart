import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class _LobbyScreenState extends ConsumerState<LobbyScreen> with SingleTickerProviderStateMixin {
  static const Color _navyTop = Color(0xFF07101F);
  static const Color _navyBottom = Color(0xFF151052);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFF7EF8A);

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

  Future<void> _handleStartGame() async {
    if (_isStarting) return;
    
    setState(() => _isStarting = true);
    AppFeedback.success();

    try {
      // ביצוע הפעולה מול הסרוויס
      await ref.read(roomServiceProvider).startGameDirectly(widget.roomId);
      
      // אנחנו לא עושים כאן setState(false) כי המסך אמור להתחלף 
      // אוטומטית ברגע שה-stream יזהה שה-phase השתנה ל-playing.
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה בהתחלת המשחק: $e')),
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
        if (room == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
          return const SizedBox();
        }

        // ניווט אוטומטי ברגע שהמשחק התחיל
        if (room.phase == GamePhase.playing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/game/${widget.roomId}');
          });
        }

        final isHost = currentUser?.id == room.hostId;
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    
                    return Column(
                      children: [
                        _buildHeader(context, currentUser, widget.roomId),
                        SizedBox(height: h * 0.02),
                        
                        // קוד חדר - קומפקטי יותר
                        SizedBox(
                          height: h * 0.16,
                          child: _RoomCodeCard(
                            code: room.code,
                            isCopied: _codeCopied,
                            onTap: () => _copyCode(room.code),
                          ),
                        ),
                        
                        SizedBox(height: h * 0.03),
                        
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'שחקנים (${room.players.length}/${GameConstants.maxPlayers})',
                            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        // רשימת שחקנים - אריחים מעט קטנים יותר כדי להרוויח מקום
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: room.players.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              mainAxisExtent: 56, 
                            ),
                            itemBuilder: (context, index) {
                              final player = room.players.values.elementAt(index);
                              return _PlayerTile(player: player, isCurrentUser: player.id == currentUser?.id);
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // כפתור התחלה - זהב פרימיום
                        SizedBox(
                          width: double.infinity,
                          height: 72,
                          child: isHost
                              ? _PremiumGoldButton(
                                  label: _isStarting ? 'מכין כספות...' : (canStart ? 'התחל משחק' : 'צריך עוד שחקנים'),
                                  enabled: canStart && !_isStarting,
                                  onTap: _handleStartGame,
                                )
                              : _WaitingCard(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
      error: (e, _) => Center(child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white))),
    );
  }

  Widget _buildHeader(BuildContext context, currentUser, String roomId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      children: [
        const Text('לובי החדר', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        GestureDetector(
          onTap: () async {
            AppFeedback.tap();
            if (currentUser != null) {
              await ref.read(roomServiceProvider).leaveRoom(roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onTap;
  const _RoomCodeCard({required this.code, required this.isCopied, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isCopied ? 'הועתק!' : 'לחץ להעתקת הקוד', style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(code, style: const TextStyle(color: Color(0xFF07101F), fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 6)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: isActive 
          ? const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFA1811A)]) 
          : LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isActive ? Colors.white54 : Colors.white10),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          PlayerAvatar(name: player.name, radius: 15, photoUrl: player.photoUrl),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isActive ? Colors.black : Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
          if (player.isHost) const Text('👑', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _PremiumGoldButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _PremiumGoldButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: enabled 
              ? [const Color(0xFFF7EF8A), const Color(0xFFD4AF37), const Color(0xFFA1811A)] 
              : [Colors.grey.shade600, Colors.grey.shade800],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            if (enabled) BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: enabled ? const Color(0xFF07101F) : Colors.white38, fontSize: 26, fontWeight: FontWeight.w900),
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text('ממתינים שהמנהל יפרוץ את הכספת...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 17, fontWeight: FontWeight.bold)),
    );
  }
}
