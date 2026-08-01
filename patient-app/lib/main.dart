import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_config.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences_storage.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

/// Must be a top-level function: the OS spawns an isolate for background
/// messages that has no access to the running app's state.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Portrait-only keeps the booking and video layouts predictable
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(PreferencesStorage(prefs)),
      ],
      child: const TouchOfCureApp(),
    ),
  );
}

class TouchOfCureApp extends ConsumerStatefulWidget {
  const TouchOfCureApp({super.key});

  @override
  ConsumerState<TouchOfCureApp> createState() => _TouchOfCureAppState();
}

class _TouchOfCureAppState extends ConsumerState<TouchOfCureApp> {
  @override
  void initState() {
    super.initState();
    // Deferred so the first frame is not blocked by permission dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider).initialise();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Clamp text scaling so large accessibility settings do not break
        // the fixed-height cards in the booking flow
        final MediaQueryData data = MediaQuery.of(context);
        return MediaQuery(
          data: data.copyWith(
            textScaler: data.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
