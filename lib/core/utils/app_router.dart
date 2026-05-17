import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../services/qa_logger_service.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/auth_lab/auth_design_lab_screen.dart';
import '../../screens/auth_lab/gpt_auth_screen.dart';
import '../../screens/auth_lab/gemini_auth_screen.dart';
import '../../screens/auth_lab/claude_auth_screen.dart';
import '../../screens/auth_lab/production_candidate_auth_screen.dart';
import '../../screens/room/create_room_screen.dart';
import '../../screens/room/join_room_screen.dart';
import '../../screens/room/lobby_screen.dart';
import '../../screens/voting/vote_image_screen.dart';
import '../../screens/voting/vote_difficulty_screen.dart';
import '../../screens/game/game_board_screen.dart';
import '../../screens/win/win_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/store/store_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  QaLoggerService.instance.log('ROUTER', 'ROUTER_INSTANCE_CREATED');
  final authState = ref.watch(firebaseUserProvider);

  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final location = state.matchedLocation;
      final onAuth = location == '/auth';
      final onSplash = location == '/splash';
      final onAuthLab = location.startsWith('/auth_lab');

      if (onSplash) {
        final dest = isLoggedIn ? '/home' : '/auth';
        QaLoggerService.instance.log('ROUTER', 'ROUTER_REDIRECT from=$location to=$dest reason=splash');
        return dest;
      }
      if (onAuthLab) {
        return null;
      }
      if (!isLoggedIn && !onAuth) {
        QaLoggerService.instance.log('ROUTER', 'ROUTER_REDIRECT from=$location to=/auth reason=not_logged_in');
        return '/auth';
      }
      if (isLoggedIn && onAuth) {
        final code = ref.read(pendingJoinCodeProvider);
        if (code != null) {
          QaLoggerService.instance.log('ROUTER', 'ROUTER_REDIRECT from=/auth to=/join-room reason=pending_code');
          return '/join-room?initialCode=$code';
        }
        QaLoggerService.instance.log('ROUTER', 'ROUTER_REDIRECT from=/auth to=/home reason=logged_in');
        return '/home';
      }
      return null;
    },
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
        path: '/auth_lab',
        builder: (context, state) => const AuthDesignLabScreen(),
      ),
      GoRoute(
        path: '/auth_lab/gpt',
        builder: (context, state) => const GptAuthScreen(),
      ),
      GoRoute(
        path: '/auth_lab/gemini',
        builder: (context, state) => const GeminiAuthScreen(),
      ),
      GoRoute(
        path: '/auth_lab/claude',
        builder: (context, state) => const ClaudeAuthScreen(),
      ),
      GoRoute(
        path: '/auth_lab/production',
        builder: (context, state) => const ProductionCandidateAuthScreen(),
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
});
