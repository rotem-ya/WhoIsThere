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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // חישוב גבהים דינמי כדי למנוע Overflow
                    double availableHeight = constraints.maxHeight;
                    
                    return Column(
                      children: [
                        // כותרת - גובה מהודק
                        _buildHeader(context, currentUser, widget.roomId),
                        
                        SizedBox(height: availableHeight * 0.02),
                        
                        // כרטיס קוד חדר - גובה יחסי
                        SizedBox(
                          height: availableHeight * 0.18,
                          child: _RoomCodeCard(
                            code: room.code,
                            isCopied: _codeCopied,
                            onTap: () => _copyCode(room.code),
                          ),
                        ),
                        
                        SizedBox(height: availableHeight * 0.03),
                        
                        // כותרת שחקנים
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('שחקנים בחדר', 
                            style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // גריד שחקנים - החלק שמתכווץ כדי להשאיר מקום לכפתור
                        Expanded(
                          child: GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: room.players.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 60,
                            ),
                            itemBuilder: (context, index) {
                              final player = room.players.values.elementAt(index);
                              return _PlayerTile(player: player, isCurrentUser: player.id == currentUser?.id);
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // כפתור הפעלה - תמיד גלוי ותמיד בתחתית
                        SizedBox(
                          width: double.infinity,
                          height: 70,
                          child: isHost
                              ? _GoldStartButton(
                                  label: _isStarting ? 'מתחיל...' : (canStart ? 'התחל משחק' : 'ממתין לשחקנים'),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: TextDirection.rtl,
      children: [
        const Text('לובי החדר', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        IconButton(
          icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white70, size: 30),
          onPressed: () async {
            if (currentUser != null) {
              await ref.read(roomServiceProvider).leaveRoom(roomId, currentUser.id);
            }
            if (context.mounted) context.go('/home');
          },
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isCopied ? 'הקוד הועתק!' : 'לחץ להעתקה', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(code, style: const TextStyle(color: Color(0xFF101936), fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: 5)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? Colors.white30 : Colors.white10),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          PlayerAvatar(name: player.name, radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isActive ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (player.isHost) const Text('👑', style: TextStyle(fontSize: 16)),
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
    return ElevatedButton(
      onPressed: enabled ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD4AF37),
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade700,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),
      child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
      child: const Text('ממתין למארח שיתחיל...', style: TextStyle(color: Colors.white70, fontSize: 18)),
    );
  }
}
