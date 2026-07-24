import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_router.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../services/sfx_service.dart';

/// Global floating notice for a pending GAME invite ("X מזמין אותך למשחק"),
/// rendered above the router like [FriendRequestBanner] so it reaches the
/// player on any screen — with a one-tap הצטרף that joins the room and opens
/// its lobby directly (no trip through the friends screen).
///
/// Suppressed during active gameplay and on auth/splash. The ✕ mutes the
/// banner until the invite set changes (the invite itself stays available in
/// the friends screen).
class GameInviteBanner extends ConsumerStatefulWidget {
  const GameInviteBanner({super.key});

  @override
  ConsumerState<GameInviteBanner> createState() => _GameInviteBannerState();
}

class _GameInviteBannerState extends ConsumerState<GameInviteBanner> {
  String _dismissedKey = '';
  String _lastNotifiedKey = '';
  bool _joining = false;

  static bool _suppressedPath(String path) =>
      path == '/' ||
      path == '/auth' ||
      path.startsWith('/splash') ||
      path.startsWith('/game/') ||
      path.startsWith('/letters/') ||
      path.startsWith('/lobby/') ||
      path.startsWith('/vote-') ||
      path.startsWith('/win/') ||
      path.startsWith('/finding-players/');

  Future<void> _join() async {
    if (_joining) return;
    final invites = ref.read(gameInvitesProvider).valueOrNull ?? const [];
    final me = ref.read(currentUserProvider).valueOrNull;
    if (invites.isEmpty || me == null) return;
    final inv = invites.first;
    setState(() => _joining = true);
    HapticFeedback.mediumImpact();
    try {
      final room = await ref.read(roomServiceProvider).joinRoom(
            code: inv.code,
            userId: me.id,
            userName: me.name,
            userPhotoUrl: me.photoUrl,
          );
      await ref.read(friendsServiceProvider).deleteGameInvite(inv.id);
      if (!mounted) return;
      if (room == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('המשחק כבר לא זמין', textDirection: TextDirection.rtl)),
        );
        return;
      }
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      ref.read(routerProvider).go('/lobby/${room.id}');
      QaLoggerService.instance
          .log('INVITE', 'BANNER_JOIN room=${room.id.substring(0, 6)}');
    } catch (e) {
      QaLoggerService.instance.log('INVITE', 'BANNER_JOIN_ERROR $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('שגיאה בהצטרפות למשחק',
                  textDirection: TextDirection.rtl)),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invites = ref.watch(gameInvitesProvider).valueOrNull ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();
    // כשגם באנר בקשות-החברות מוצג — יורדים שורה כדי לא לחפוף אותו.
    final friendBannerVisible =
        (ref.watch(friendRequestsProvider).valueOrNull ?? const [])
            .isNotEmpty;

    final router = ref.watch(routerProvider);
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        final key = invites.map((i) => '${i.id}:${i.roomId}').join(',');
        if (_suppressedPath(path) || key == _dismissedKey) {
          return const SizedBox.shrink();
        }
        // A new/changed invite is about to slide in → chime once.
        if (key != _lastNotifiedKey) {
          _lastNotifiedKey = key;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SfxService.instance.notify();
          });
        }

        final first = invites.first;
        final fromName = first.fromName.isEmpty ? 'חבר' : first.fromName;
        final text = invites.length == 1
            ? '$fromName מזמין אותך למשחק! 🎮'
            : '$fromName ועוד ${invites.length - 1} מזמינים אותך למשחק! 🎮';

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(key),
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Transform.translate(
                offset: Offset(0, -40 * (1 - t)),
                child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: EdgeInsets.fromLTRB(
                      12, friendBannerVisible ? 60 : 8, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D3325), Color(0xFF0A2318)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFF34D399).withOpacity(0.55),
                        width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF34D399).withOpacity(0.18),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎮', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _joining ? null : _join,
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 34),
                        ),
                        child: _joining
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF34D399)),
                              )
                            : const Text(
                                'הצטרף',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _dismissedKey = key),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 34, minHeight: 34),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
