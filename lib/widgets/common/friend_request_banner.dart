import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_styles.dart';
import '../../core/utils/app_router.dart';
import '../../providers/providers.dart';

/// Global floating notice for pending friend requests. Rendered ABOVE the
/// router (via MaterialApp.builder) so it is visible on every screen — the
/// tiny red dot on the home 👥 button required already being on the right
/// screen to notice. Tapping navigates to the friends screen; the ✕ mutes
/// the notice until the set of pending requests changes.
///
/// Suppressed during active gameplay (game/lobby/vote/win/letters) and on
/// auth/splash so it never covers the board or the sign-in flow.
class FriendRequestBanner extends ConsumerStatefulWidget {
  const FriendRequestBanner({super.key});

  @override
  ConsumerState<FriendRequestBanner> createState() =>
      _FriendRequestBannerState();
}

class _FriendRequestBannerState extends ConsumerState<FriendRequestBanner> {
  // The request-id set that was dismissed; a new/changed set shows again.
  String _dismissedKey = '';

  static bool _suppressedPath(String path) =>
      path == '/' ||
      path == '/auth' ||
      path == '/friends' ||
      path.startsWith('/splash') ||
      path.startsWith('/game/') ||
      path.startsWith('/letters/') ||
      path.startsWith('/lobby/') ||
      path.startsWith('/vote-') ||
      path.startsWith('/win/') ||
      path.startsWith('/finding-players/');

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(friendRequestsProvider).valueOrNull ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    final router = ref.watch(routerProvider);
    return AnimatedBuilder(
      animation: router.routeInformationProvider,
      builder: (context, _) {
        final path = router.routeInformationProvider.value.uri.path;
        final key = requests.map((r) => r.id).join(',');
        if (_suppressedPath(path) || key == _dismissedKey) {
          return const SizedBox.shrink();
        }

        final text = requests.length == 1
            ? 'בקשת חברות חדשה מ${requests.first.fromName.isNotEmpty ? "־${requests.first.fromName}" : "חבר"}'
            : '${requests.length} בקשות חברות ממתינות לך';

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
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2A40), Color(0xFF0A1B2E)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppStyles.cyanGlow.withOpacity(0.55),
                        width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppStyles.cyanGlow.withOpacity(0.18),
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
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          router.go('/friends');
                        },
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 34),
                        ),
                        child: const Text(
                          'צפה',
                          style: TextStyle(
                            color: AppStyles.cyanGlow,
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
