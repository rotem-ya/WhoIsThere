import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/game/game_board_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/room/create_room_screen.dart';
import '../../screens/room/join_room_screen.dart';
import '../../screens/room/lobby_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/store/store_screen.dart';
import '../../screens/voting/vote_difficulty_screen.dart';
import '../../screens/voting/vote_image_screen.dart';
import '../../screens/win/win_screen.dart';

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
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/create-room',
        builder: (context, state) => const CreateRoomScreen(),
      ),
      GoRoute(
        path: '/join-room',
        builder: (context, state) => JoinRoomScreen(
          initialCode: state.uri.queryParameters['initialCode'],
        ),
      ),
      GoRoute(
        path: '/lobby/:roomId',
        builder: (context, state) =>
            LobbyScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/vote-image/:roomId',
        builder: (context, state) =>
            VoteImageScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/vote-difficulty/:roomId',
        builder: (context, state) =>
            VoteDifficultyScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/game/:roomId',
        builder: (context, state) =>
            GameBoardScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/win/:roomId',
        builder: (context, state) =>
            WinScreen(roomId: state.pathParameters['roomId']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/store',
        builder: (context, state) => const StoreScreen(),
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
      (_, __) => notifyListeners(),
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
