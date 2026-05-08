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
  static const Color _navyCard = Color(0xFF0A1324);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _cyan = Color(0xFF87CEEB);

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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    
                    return Column(
                      children: [
                        // Header
                        _buildHeader(context, currentUser, widget.roomId),
                        
                        SizedBox(height: h * 0.02),
                        
                        // כפתור קוד החדר החדש - מרובע מוזהב יוקרתי
                        SizedBox(
                          height: h * 0.18,
                          child: _RoomCodeButton( // שונה ל-Button
                            code: room.code,
                            isCopied: _codeCopied,
                            onTap: () => _copyCode(room.code),
                          ),
                        ),
                        
                        SizedBox(height: h * 0.03),
                        
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('שחקנים בחדר', 
                            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // גריד שחקנים - מתכווץ
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
                              return _PlayerTile(player: player, isCurrentUser: player.id == currentUser?.id);
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // כפתור הפעלה
                        SizedBox(
                          height: 68,
                          child: isHost
                              ? _GoldStartButton(
                                  label: _isStarting ? 'מכין כספות...' : (canStart ? 'התחל משחק' : 'ממתין לשחקנים'),
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
      error: (e, _) => Center(child: Text('שגיאה: $e')),
    );
  }

  Widget _buildHeader(BuildContext context, currentUser, String roomId) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        GestureDetector(
          onTap: () async {
            if (currentUser != null) {
              await ref.read(roomServiceProvider).leaveRoom(roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
            child: const Icon(Icons.logout_rounded, color: Colors.white, size: 26),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('לובי הכספת', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 46), // לאיזון המרכוז
      ],
    );
  }
}

// הווידג'ט החדש: כפתור קוד חדר מוזהב ומהודק
class _RoomCodeButton extends StatelessWidget {
  final String code;
  final bool isCopied;
  final VoidCallback onTap;
  const _RoomCodeButton({required this.code, required this.isCopied, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        decoration: BoxDecoration(
          // גרדיאנט מוזהב יוקרתי, בדומה לאריחי המשחק
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7EF8A), Color(0xFFD4AF37), Color(0xFFA1811A)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCopied ? _LobbyScreenState._cyan : Colors.white60,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            if (isCopied)
              BoxShadow(color: _LobbyScreenState._cyan.withOpacity(0.6), blurRadius: 30, spreadRadius: 4),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // אייקון מנעול קטן מעל הקוד
            Icon(Icons.lock_person_rounded, color: const Color(0xFF07101F).withOpacity(0.8), size: 28),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  code,
                  style: const TextStyle(
                    color: Color(0xFF07101F), // כהה על זהב
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(isCopied ? 'הועתק ✓' : 'לחץ להעתקה', style: TextStyle(color: const Color(0xFF07101F).withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
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
        color: isActive ? _LobbyScreenState._gold : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isActive ? Colors.white30 : Colors.white10),
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
          if (player.isHost) const Text('👑', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _GoldStartButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _GoldStartButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE27A), Color(0xFFD4AF37), Color(0xFFA1811A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (enabled) BoxShadow(color: const Color(0xFFD4AF37).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Center(
            child: Text(label, style: const TextStyle(color: Color(0xFF07101F), fontSize: 24, fontWeight: FontWeight.w900)),
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
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(18)),
      child: const Text('ממתין למארח שיתחיל...', style: TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
