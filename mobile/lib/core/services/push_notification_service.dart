import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

/// Registers the current device with the backend and keeps its FCM token fresh.
///
/// The backend remains the source of truth for notification records and delivery
/// targeting. This service only owns the mobile FCM lifecycle.
class PushNotificationService {
  PushNotificationService(this._api);

  final ApiClient _api;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _started = false;

  Future<void> initialize() async {
    if (_started || kIsWeb) return;
    _started = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _registerCurrentToken(),
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      _registerToken(token);
    });

    await _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error, stackTrace) {
      debugPrint('FCM token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _registerToken(String token) async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    try {
      await _api.post(
        '/notifications/device-tokens',
        body: {
          'token': token,
          'platform': defaultTargetPlatform.name,
        },
      );
    } catch (error, stackTrace) {
      // A transient backend/network failure must not prevent the app from
      // starting. The next auth/token refresh will retry registration.
      debugPrint('Unable to sync FCM token: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    _authSubscription = null;
    _tokenSubscription = null;
    _started = false;
  }
}
