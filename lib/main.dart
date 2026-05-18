import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'core/constants/build_info.dart';
import 'core/theme/app_styles.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'firebase_options.dart';
import 'providers/providers.dart';
import 'services/qa_logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      firebaseError = e;
    }
  } catch (e) {
    firebaseError = e;
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Light icons/text on status bar — the new background is blue, not dark navy.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS equivalent
    ),
  );

  await QaLoggerService.instance.init();
  QaLoggerService.instance.log('APP', 'APP_START build=$kBuildLabel');

  if (firebaseError != null) {
    runApp(_ErrorApp(error: firebaseError.toString()));
    return;
  }

  runApp(const ProviderScope(child: GuessThePlaceApp()));
}

class _ErrorApp extends StatelessWidget {
  final String error;
  const _ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('he'), Locale('en')],
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppStyles.backgroundGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  const Text(
                    'Startup Error',
                    style: AppStyles.heading2,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppStyles.glassCard(radius: 12),
                    child: SelectableText(
                      error,
                      style: AppStyles.bodySmall.copyWith(
                        fontFamily: 'monospace',
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GuessThePlaceApp extends ConsumerStatefulWidget {
  const GuessThePlaceApp({super.key});

  @override
  ConsumerState<GuessThePlaceApp> createState() => _GuessThePlaceAppState();
}

class _GuessThePlaceAppState extends ConsumerState<GuessThePlaceApp> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    // Cold start — app launched via deep link
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _handleDeepLink(initial, coldStart: true);
    } catch (_) {}

    // Warm start — app already running, new link arrives
    _linkSub = appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri, coldStart: false),
      onError: (_) {},
    );
  }

  void _handleDeepLink(Uri uri, {required bool coldStart}) {
    final isCustomScheme = uri.scheme == 'whoisthere' && uri.host == 'join';
    final isAppLink = uri.scheme == 'https' &&
        uri.host == 'rotem-ya.github.io' &&
        uri.path.startsWith('/apps-share-pages/whoisthere/join');
    if (!isCustomScheme && !isAppLink) return;

    final raw = uri.queryParameters['code'] ?? '';
    final code = raw.trim().toUpperCase();
    if (code.length != 6 || !RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) return;

    if (coldStart) {
      // Store for GoRouter redirect to pick up after auth
      ref.read(pendingJoinCodeProvider.notifier).state = code;
      return;
    }

    // Warm start — only navigate if not in an active game session
    final router = ref.read(routerProvider);
    final currentPath =
        router.routeInformationProvider.value.uri.path;
    final inActiveGame = currentPath.startsWith('/game/') ||
        currentPath.startsWith('/vote-') ||
        currentPath.startsWith('/win/') ||
        currentPath.startsWith('/lobby/');

    if (!inActiveGame) {
      router.go('/join-room?initialCode=$code');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch keeps the Riverpod provider alive — do not remove.
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Guess the Place',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('he'),
      supportedLocales: const [Locale('he'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
