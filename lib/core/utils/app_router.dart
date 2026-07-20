import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/game/game_board_screen.dart';
import '../../screens/game/letters_game_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/friends/friends_screen.dart';
import '../../screens/room/create_room_screen.dart';
import '../../screens/room/join_room_screen.dart';
import '../../screens/room/finding_players_screen.dart';
import '../../screens/room/lobby_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/store/store_screen.dart';
import '../../screens/store/card_skins_screen.dart';
import '../../screens/store/board_skins_screen.dart';
import '../../screens/store/avatars_screen.dart';
import '../../screens/voting/vote_difficulty_screen.dart';
import '../../screens/voting/vote_image_screen.dart';
import '../../screens/win/win_screen.dart';

/// A gentle fade-through page transition (fade + tiny upward drift + subtle
/// settle-in scale) used for every route, replacing the platform-default page
/// cut. It follows the Material "fade through" feel: the incoming screen fades
/// and scales up from 0.98 so it reads as arriving with depth rather than a
/// flat cross-fade. Kept short (240ms) so navigation still feels snappy. Honors
/// the OS "reduce motion" accessibility setting by dropping the animation.
CustomTransitionPage<void> _fadeThroughPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Created exactly once. Auth changes are handled via [_RouterNotifier] +
/// [GoRouter.refreshListenable] — the router instance is never recreated.
final routerProvider = Provider<GoRouter>((ref) {
  QaLoggerService.instance.log('ROUTER', 'ROUTER_INSTANCE_CREATED');

  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: '/auth',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const SplashScreen()),
      ),
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const AuthScreen()),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const HomeScreen()),
      ),
      GoRoute(
        path: '/create-room',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const CreateRoomScreen()),
      ),
      GoRoute(
        path: '/join-room',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          JoinRoomScreen(
            initialCode: state.uri.queryParameters['initialCode'],
          ),
        ),
      ),
      GoRoute(
        path: '/lobby/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          LobbyScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/finding-players/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          FindingPlayersScreen(
            roomId: state.pathParameters['roomId']!,
            targetPlayers:
                int.tryParse(state.uri.queryParameters['target'] ?? '2') ?? 2,
          ),
        ),
      ),
      GoRoute(
        path: '/vote-image/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          VoteImageScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/vote-difficulty/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          VoteDifficultyScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/game/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          GameBoardScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/letters/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          LettersGameScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/win/:roomId',
        pageBuilder: (context, state) => _fadeThroughPage(
          state,
          WinScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const ProfileScreen()),
      ),
      GoRoute(
        path: '/friends',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const FriendsScreen()),
      ),
      GoRoute(
        path: '/store',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const StoreScreen()),
      ),
      GoRoute(
        path: '/store/skins',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const CardSkinsScreen()),
      ),
      GoRoute(
        path: '/store/board',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const BoardSkinsScreen()),
      ),
      GoRoute(
        path: '/store/avatars',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const AvatarsScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            _fadeThroughPage(state, const SettingsScreen()),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});

/// Listens to [firebaseUserProvider] and notifies GoRouter to re-run
/// redirect logic — without recreating the [GoRouter] instance.
class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<User?>>(
      firebaseUserProvider,
      (previous, next) {
        // Firebase can re-emit the same User on token refresh. Only refresh
        // the router when the actual login status changes (null <-> User).
        if (next.isLoading) return;
        final wasLoggedIn = previous?.valueOrNull != null;
        final isLoggedIn = next.valueOrNull != null;

        final prevUser = previous?.valueOrNull;
        final nextUser = next.valueOrNull;
        QaLoggerService.instance.log(
          'ROUTER',
          'ROUTER_AUTH_STATE '
          'uid=${nextUser?.uid ?? "null"} '
          'anonymous=${nextUser?.isAnonymous} '
          'providers=${nextUser?.providerData.map((p) => p.providerId).join(",") ?? "none"}',
        );

        // When the user upgrades from anonymous → non-anonymous, the Firestore
        // SDK may still hold the old anonymous token. Force-refresh here so the
        // first post-login write succeeds without permission-denied.
        final wasAnonymous = prevUser?.isAnonymous ?? true;
        final isNonAnonymous = nextUser != null && !nextUser.isAnonymous;
        if (wasAnonymous && isNonAnonymous) {
          nextUser.getIdToken(true).catchError((_) => '');
        }

        if (wasLoggedIn != isLoggedIn) notifyListeners();
      },
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(firebaseUserProvider);
    if (authState.isLoading) return null;

    final isLoggedIn = authState.value != null;
    final location = state.matchedLocation;
    final onAuth = location == '/auth';
    final onSplash = location == '/splash';

    if (onSplash) {
      final dest = isLoggedIn ? '/home' : '/auth';
      QaLoggerService.instance.log(
          'ROUTER', 'ROUTER_REDIRECT from=$location to=$dest reason=splash');
      return dest;
    }
    if (!isLoggedIn && !onAuth) {
      QaLoggerService.instance.log(
          'ROUTER', 'ROUTER_REDIRECT from=$location to=/auth reason=not_logged_in');
      return '/auth';
    }
    if (isLoggedIn && onAuth) {
      final code = _ref.read(pendingJoinCodeProvider);
      if (code != null) {
        QaLoggerService.instance.log(
            'ROUTER', 'ROUTER_REDIRECT from=/auth to=/join-room reason=pending_code');
        return '/join-room?initialCode=$code';
      }
      QaLoggerService.instance.log(
          'ROUTER', 'ROUTER_REDIRECT from=/auth to=/home reason=logged_in');
      return '/home';
    }
    return null;
  }
}
