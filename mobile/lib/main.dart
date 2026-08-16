import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/router.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
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
    await FirebaseMessaging.instance.requestPermission();
  }

  runApp(const ProviderScope(child: ArenaHubApp()));
}

class ArenaHubApp extends StatelessWidget {
  const ArenaHubApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'ArenaHub',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: ArenaTheme.dark(),
      );
}
