import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'core/constants/ad_constants.dart';
import 'core/constants/build_info.dart';
import 'core/theme/app_styles.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';
import 'models/user_model.dart';
import 'providers/providers.dart';
import 'services/content_manifest_service.dart';
import 'services/cosmetics_catalog_service.dart';
import 'services/notification_service.dart';
import 'services/qa_logger_service.dart';
import 'services/report_service.dart';
import 'widgets/common/friend_request_banner.dart';
import 'widgets/common/game_invite_banner.dart';
import 'widgets/common/group_invite_banner.dart';
import 'widgets/common/rank_up_banner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/settings_service.dart';

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

  // Register the FCM background handler as early as possible (must be a
  // top-level function). Best-effort — never block startup on it.
  if (firebaseError == null) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }

  // AdMob is initialized AFTER the App Tracking Transparency prompt (see
  // _GuessThePlaceAppState._initTrackingThenAds) so, on iOS, the ATT dialog is
  // shown before any ad SDK reads the advertising identifier. Not initialized
  // here.

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

  // Capture otherwise-fatal uncaught errors into the QA log and keep the app
  // alive. A stray Dart exception on a screen (e.g. the win/finished flow) is
  // turned into a logged, non-fatal event instead of tearing the process down;
  // if a crash still occurs with no CRASH entry, the cause is native (plugin).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    final msg = details.exceptionAsString();
    QaLoggerService.instance.log(
        'CRASH', 'FLUTTER_ERROR ${msg.length > 160 ? msg.substring(0, 160) : msg}');
    // Auto-send the crash + recent log to Firestore (throttled, fail-soft).
    ReportService.instance.reportCrash(
        kind: 'flutter', error: details.exception, stack: details.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    final msg = error.toString();
    QaLoggerService.instance.log(
        'CRASH', 'UNCAUGHT ${msg.length > 160 ? msg.substring(0, 160) : msg}');
    ReportService.instance.reportCrash(kind: 'uncaught', error: error, stack: stack);
    return true; // handled — keep the app running
  };

  await SettingsService.init();
  final platform = Platform.operatingSystem; // android / ios / linux / ...
  final utcNow = DateTime.now().toUtc();
  final utcTs =
      '${utcNow.year}-${_p2(utcNow.month)}-${_p2(utcNow.day)}'
      'T${_p2(utcNow.hour)}:${_p2(utcNow.minute)}:${_p2(utcNow.second)}Z';
  QaLoggerService.instance.log(
    'APP',
    'APP_START build=$kBuildLabel branch=$kGitBranch version=$kAppVersion platform=$platform utc=$utcTs',
  );

  if (firebaseError != null) {
    runApp(_ErrorApp(error: firebaseError.toString()));
    return;
  }

  // Disable Firestore offline persistence. A corrupted on-disk cache (LevelDB)
  // is the leading cause of a deterministic NATIVE crash on the first doc
  // .get() — observed when entering Quick Game (crash inside the exposure read,
  // before any catchable Dart frame). Live multiplayer doesn't need offline
  // reads, so memory-only is safe. Must run before any Firestore use (the first
  // is the wallet read, which happens after runApp).
  try {
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: false);
    QaLoggerService.instance.log('APP', 'FIRESTORE_PERSISTENCE_DISABLED');
  } catch (e) {
    QaLoggerService.instance.log('APP', 'FIRESTORE_SETTINGS_FAIL error=$e');
  }

  // Hybrid content manifest — apply the last-known state instantly (offline-safe)
  // then subscribe LIVE to Firestore so admin edits appear immediately in the
  // running game (no restart). Best-effort: never blocks startup or game start;
  // on any failure the game uses bundled content. The live listener's first
  // event also serves as the initial refresh (replaces the one-shot sync()).
  await ContentManifestService.instance.loadCached();
  ContentManifestService.instance.startRealtime();

  // Live store-cosmetics catalog — same architecture: cached instantly,
  // realtime for admin edits, bundled fallback on any failure.
  await CosmeticsCatalogService.instance.loadCached();
  CosmeticsCatalogService.instance.startRealtime();

  runApp(const ProviderScope(child: GuessThePlaceApp()));
}

String _p2(int n) => n.toString().padLeft(2, '0');

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

class _GuessThePlaceAppState extends ConsumerState<GuessThePlaceApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;

  String? _pushedTokenForUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    _initTrackingThenAds();
    _initPush();
    _touchLastSeen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _touchLastSeen();
  }

  /// Refresh the signed-in user's lastSeenAt (admin "recently connected" list).
  /// Throttled + fail-soft inside AuthService.
  void _touchLastSeen() {
    try {
      final auth = ref.read(authServiceProvider);
      auth.touchLastSeen();
      // v1.3: החזר מטבעות חד-פעמי לרוכשי אפקטי ניצחון (הוסרו מהחנות).
      unawaited(auth.refundRetiredWinEffects());
    } catch (_) {}
  }

  Future<void> _initPush() async {
    // Tapping a push (friend game invite) opens the friends screen, where the
    // invite banner lets the user jump straight into the room.
    NotificationService.instance.onMessageOpened = (message) {
      try {
        final router = ref.read(routerProvider);
        final currentPath = router.routeInformationProvider.value.uri.path;
        final inActiveGame = currentPath.startsWith('/game/') ||
            currentPath.startsWith('/letters/') ||
            currentPath.startsWith('/vote-') ||
            currentPath.startsWith('/win/') ||
            currentPath.startsWith('/lobby/');
        if (inActiveGame) return;
        // הזמנת משחק: קפיצה ישירה ללובי של המזמין (בלי תחנת ביניים במסך
        // החברים). נכשל/חסר קוד → נופל למסך החברים, שם הבאנר ממתין.
        if (message.data['type'] == 'game_invite' &&
            (message.data['code'] as String? ?? '').isNotEmpty) {
          unawaited(_joinFromPush(
              message.data['code'] as String, router));
          return;
        }
        router.go('/friends');
      } catch (_) {}
    };
    await NotificationService.instance.init();
  }

  /// Joins a room straight from a tapped game-invite push or a join deep
  /// link. Waits briefly for the signed-in user on cold start; any failure
  /// lands on [fallbackPath] (friends screen for pushes, the join screen with
  /// the code pre-filled for links).
  Future<void> _joinFromPush(String code, GoRouter router,
      {String fallbackPath = '/friends'}) async {
    try {
      UserModel? me = ref.read(currentUserProvider).valueOrNull;
      for (var i = 0; i < 20 && me == null; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        me = ref.read(currentUserProvider).valueOrNull;
      }
      if (me == null) {
        router.go(fallbackPath);
        return;
      }
      final room = await ref.read(roomServiceProvider).joinRoom(
            code: code,
            userId: me.id,
            userName: me.name,
            userPhotoUrl: me.photoUrl,
          );
      if (room == null) {
        router.go(fallbackPath);
        return;
      }
      ref.read(currentRoomIdProvider.notifier).state = room.id;
      router.go('/lobby/${room.id}');
      QaLoggerService.instance
          .log('INVITE', 'PUSH_JOIN room=${room.id.substring(0, 6)}');
    } catch (e) {
      QaLoggerService.instance.log('INVITE', 'PUSH_JOIN_ERROR $e');
      try {
        router.go(fallbackPath);
      } catch (_) {}
    }
  }

  /// iOS App Tracking Transparency: request authorization once the app is
  /// active (a post-frame callback guarantees it's foregrounded), THEN
  /// initialize AdMob. Apple requires the ATT prompt to appear before any ad
  /// SDK reads the advertising identifier. Fail-soft and a no-op when ads are
  /// disabled; on Android requestTrackingAuthorization simply returns.
  Future<void> _initTrackingThenAds() async {
    if (!AdConstants.adsEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // Small delay so the prompt lands after the first frame is visible
          // (iOS silently drops it if requested while not yet active).
          await Future<void>.delayed(const Duration(milliseconds: 400));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      } catch (_) {
        // Non-iOS or plugin error — proceed to ads regardless.
      }
      try {
        MobileAds.instance.initialize();
      } catch (_) {}
    });
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
    // ── Friend-invite links — add the inviter as a friend automatically ──────
    // Hosts that serve our pages: Firebase Hosting (canonical) + the two
    // legacy GitHub Pages hosts (links shared by older builds).
    final isOurWebHost = uri.host == 'whoisthere-380fa.web.app' ||
        uri.host == 'whoisthere-380fa.firebaseapp.com' ||
        uri.host == 'rotem-ya.github.io';

    final isFriendScheme = uri.scheme == 'whoisthere' && uri.host == 'friend';
    final isFriendAppLink = uri.scheme == 'https' &&
        isOurWebHost &&
        (uri.path.startsWith('/friend') ||
            uri.path.startsWith('/apps-share-pages/whoisthere/friend') ||
            uri.path.startsWith('/WhoIsThere/friend'));
    if (isFriendScheme || isFriendAppLink) {
      final rawF = uri.queryParameters['code'] ?? '';
      final friendCode = rawF.trim().toUpperCase();
      // Friend codes are 6–8 uppercase letters/digits.
      if (!RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(friendCode)) return;
      ref.read(pendingFriendCodeProvider.notifier).state = friendCode;
      if (!coldStart) {
        final router = ref.read(routerProvider);
        final currentPath = router.routeInformationProvider.value.uri.path;
        final inActiveGame = currentPath.startsWith('/game/') ||
            currentPath.startsWith('/vote-') ||
            currentPath.startsWith('/win/') ||
            currentPath.startsWith('/lobby/');
        if (!inActiveGame) router.go('/friends');
      }
      return;
    }

    final isCustomScheme = uri.scheme == 'whoisthere' && uri.host == 'join';
    final isAppLink = uri.scheme == 'https' &&
        isOurWebHost &&
        (uri.path.startsWith('/join') ||
            uri.path.startsWith('/apps-share-pages/whoisthere/join'));
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
      // הצטרפות ישירה לחדר מהקישור; אם החדר כבר לא זמין — מסך ההצטרפות
      // עם הקוד ממולא (המסלול הישן).
      unawaited(_joinFromPush(code, router,
          fallbackPath: '/join-room?initialCode=$code'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch keeps the Riverpod provider alive — do not remove.
    final router = ref.watch(routerProvider);

    // Bind this device's FCM token to the signed-in user so the invite Cloud
    // Function can reach them. Runs once per uid (guarded), fail-soft.
    ref.listen(firebaseUserProvider, (prev, next) {
      final uid = next.valueOrNull?.uid;
      if (uid != null && uid != _pushedTokenForUid) {
        _pushedTokenForUid = uid;
        NotificationService.instance.registerTokenForUser(uid);
      }
    });

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
        // Clamp the system text scale: game layouts are designed for ~1.0 and
        // Android devices with enlarged fonts (1.3-2.0) blow them apart while
        // iOS stays at 1.0 and looks right. A small allowance keeps some
        // accessibility benefit without breaking screens.
        final mq = MediaQuery.of(context);
        // בקשת רותם (2026-07-11): כיתוב קטן במעט בכל האפליקציה - מקדם 0.95
        // אחרי ה-clamp המגן מפני פונטים מוגדלים של המערכת.
        // בקשת רותם (2026-07-16): באנדרואיד הכיתוב עדיין גדול מדי גם אחרי
        // ה-0.95 (באייפון כבר טוב) - מקדם נוסף רק לאנדרואיד.
        final platformFactor = Platform.isAndroid ? 0.9 : 1.0;
        final scale =
            mq.textScaler.scale(1.0).clamp(0.85, 1.1) * 0.95 * platformFactor;
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            // The friend-request banner floats above the router so a pending
            // request is noticeable from ANY screen (not just the home dot).
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                const FriendRequestBanner(),
                // הזמנות משחק — באנר גלובלי עם "הצטרף" ישיר ללובי.
                const GameInviteBanner(),
                // הזמנות קבוצה — מחייב אישור מפורש (הצטרף/דחה) לפני חברות.
                const GroupInviteBanner(),
                // חגיגת עליית דרגה — צפה ב-totalPoints וחוגג מעבר דרגה.
                const RankUpBanner(),
              ],
            ),
          ),
        );
      },
    );
  }
}
