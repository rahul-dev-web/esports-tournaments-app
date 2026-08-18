import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/services/api_client.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

FirebaseOptions? _firebaseWebOptions() {
  if (firebaseApiKey.isEmpty ||
      firebaseProjectId.isEmpty ||
      firebaseMessagingSenderId.isEmpty ||
      firebaseAppId.isEmpty) {
    return null;
  }

  return FirebaseOptions(
    apiKey: firebaseApiKey,
    authDomain: firebaseAuthDomain.isNotEmpty ? firebaseAuthDomain : null,
    projectId: firebaseProjectId,
    storageBucket: firebaseStorageBucket.isNotEmpty ? firebaseStorageBucket : null,
    messagingSenderId: firebaseMessagingSenderId,
    appId: firebaseAppId,
    measurementId: firebaseMeasurementId.isNotEmpty ? firebaseMeasurementId : null,
  );
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) {
    final service = PushNotificationService(ApiClient());
    ref.onDispose(service.dispose);
    return service;
  },
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[AUTH_DEBUG] ===== APP START =====');
  debugPrint('[AUTH_DEBUG] supabaseConfigured=${supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty}');
  debugPrint('[AUTH_DEBUG] supabaseUrl=$supabaseUrl');
  debugPrint('[AUTH_DEBUG] oauthRedirectUrl=$oauthRedirectUrl');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );

    debugPrint('[AUTH_DEBUG] Supabase.initialize() completed');
    debugPrint('[AUTH_DEBUG] initialSession=${Supabase.instance.client.auth.currentSession != null}');
  }

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  if (kIsWeb) {
    final options = _firebaseWebOptions();
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      debugPrint('Firebase web options are not configured; skipping Firebase.initializeApp() on web.');
    }
  } else {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const ProviderScope(child: ArenaHubApp()));
}

class ArenaHubApp extends ConsumerStatefulWidget {
  const ArenaHubApp({super.key});

  @override
  ConsumerState<ArenaHubApp> createState() => _ArenaHubAppState();
}

class _ArenaHubAppState extends ConsumerState<ArenaHubApp> {
  StreamSubscription<AuthState>? _authDebugSubscription;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      ref.read(pushNotificationServiceProvider).initialize();
    }

    _authDebugSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      debugPrint(
        '[AUTH_DEBUG] GLOBAL AUTH EVENT: event=${authState.event.name}, session=${authState.session != null}',
      );
      debugPrint('[AUTH_DEBUG] GLOBAL AUTH USER PRESENT=${authState.session?.user != null}');
    });
  }

  @override
  void dispose() {
    debugPrint('[AUTH_DEBUG] ArenaHubApp disposed; cancelling global auth debug listener');
    _authDebugSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'ArenaHub',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: ArenaTheme.dark(),
      );
}
