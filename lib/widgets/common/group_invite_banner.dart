import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_router.dart';
import '../../providers/providers.dart';

/// Global floating notice for a pending GROUP invite ("X מזמין אותך לקבוצה"),
/// rendered above the router like [FriendRequestBanner]/[GameInviteBanner] so
/// it reaches the player on any screen. Unlike a game invite, joining a group
/// requires explicit consent (WhatsApp-style) — the two buttons here are
/// הצטרף (accept, becomes a member) and דחה (decline, invite just deleted).
///
/// Suppressed during active gameplay and on auth/splash. Stacks below the
/// friend-request and game-invite banners when they're also visible.
class GroupInviteBanner extends ConsumerStatefulWidget {
  const GroupInviteBanner({super.key});

  @override
  ConsumerState<GroupInviteBanner> createState() => _GroupInviteBannerState();
}

class _GroupInviteBannerState extends ConsumerState<GroupInviteBanner> {
  String _dismissedKey = '';
  bool _busy = false;
  final Set<String> _markedReadIds = {};

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

  Future<void> _accept() async {
    if (_busy) return;
    final invites = ref.read(pendingGroupInvitesProvider).valueOrNull ?? const [];
    final me = ref.read(currentUserProvider).valueOrNull;
    if (invites.isEmpty || me == null) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(groupsServiceProvider)
          .acceptGroupInvite(invites.first, me.name);
    } catch (_) {
      // Best-effort — the invite stays pending and the card in the groups
      // tab still offers a retry.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    final invites = ref.read(pendingGroupInvitesProvider).valueOrNull ?? const [];
    if (invites.isEmpty) return;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      await ref.read(groupsServiceProvider).declineGroupInvite(invites.first);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invites =
        ref.watch(pendingGroupInvitesProvider).valueOrNull ?? const [];
    if (invites.isEmpty) return const SizedBox.shrink();

    // כשגם באנר הבקשות וגם באנר הזמנות המשחק מוצגים, יורדים בהתאם כדי לא
    // לחפוף אותם.
    final friendBannerVisible =
        (ref.watch(friendRequestsProvider).valueOrNull ?? const []).isNotEmpty;
    final gameBannerVisible =
        (ref.watch(gameInvitesProvider).valueOrNull ?? const []).isNotEmpty;
    final topOffset =
        8.0 + (friendBannerVisible ? 52 : 0) + (gameBannerVisible ? 52 : 0);

    final router = ref.watch(routerProvider);
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        final key = invites.map((i) => i.id).join(',');
        if (_suppressedPath(path) || key == _dismissedKey) {
          return const SizedBox.shrink();
        }

        // This banner being on screen right now means the player has seen
        // it — mark every currently-listed invite read (fire-and-forget; no
        // rebuild needed, so safe to do from inside build).
        for (final inv in invites) {
          if (_markedReadIds.add(inv.id)) {
            ref.read(groupsServiceProvider).markGroupInviteRead(inv.id);
          }
        }

        final first = invites.first;
        final fromName = first.fromName.isEmpty ? 'חבר' : first.fromName;
        final text = invites.length == 1
            ? '$fromName מזמין אותך לקבוצה "${first.groupName}" 👥'
            : '$fromName ועוד ${invites.length - 1} הזמנות קבוצה ממתינות לך';

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
                  margin: EdgeInsets.fromLTRB(12, topOffset, 12, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10331F), Color(0xFF0A2116)],
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
                      const Text('👥', style: TextStyle(fontSize: 20)),
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
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF34D399)),
                          ),
                        )
                      else ...[
                        TextButton(
                          onPressed: _accept,
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 34),
                          ),
                          child: const Text(
                            'הצטרף',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _decline,
                          style: TextButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 34),
                          ),
                          child: const Text(
                            'דחה',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: () => setState(() => _dismissedKey = key),
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 30, minHeight: 30),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 16),
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
