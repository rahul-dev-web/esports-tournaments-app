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

  debugPrint('[APP AUTH 00] ArenaHub main() started');
  debugPrint('[APP AUTH 00] Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');
  debugPrint('[APP AUTH 00] Initial URI: ${Uri.base}');
  debugPrint('[APP AUTH 00] OAuth redirect configured as: $oauthRedirectUrl');
  debugPrint('[APP AUTH 00] Supabase URL configured: ${supabaseUrl.isNotEmpty}');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );

    debugPrint('[APP AUTH 00] Supabase.initialize() completed');
    debugPrint('[APP AUTH 00] Session immediately after initialization: ${Supabase.instance.client.auth.currentSession != null}');

    Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      final session = authState.session;
      debugPrint('[APP AUTH EVENT] ========================================');
      debugPrint('[APP AUTH EVENT] Event: ${authState.event}');
      debugPrint('[APP AUTH EVENT] URI: ${Uri.base}');
      debugPrint('[APP AUTH EVENT] Session: ${session != null ? 'FOUND' : 'NULL'}');
      debugPrint('[APP AUTH EVENT] User ID: ${session?.user.id ?? 'NULL'}');
      debugPrint('[APP AUTH EVENT] Email: ${session?.user.email ?? 'NULL'}');
      debugPrint('[APP AUTH EVENT] Access token: ${session?.accessToken.isNotEmpty == true ? 'PRESENT' : 'MISSING'}');
      debugPrint('[APP AUTH EVENT] ========================================');
    });
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
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      ref.read(pushNotificationServiceProvider).initialize();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'ArenaHub',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: ArenaTheme.dark(),
      );
}
