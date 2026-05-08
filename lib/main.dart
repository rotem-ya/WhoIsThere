import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_styles.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_router.dart';
import 'firebase_options.dart';

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

class GuessThePlaceApp extends ConsumerWidget {
  const GuessThePlaceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
