import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'local_notification_service.dart';

/// Owns the mobile FCM lifecycle.
///
/// The backend is the source of truth for notification records and device
/// targeting. This service handles Firebase permission/token lifecycle and
/// synchronises the current device token with the backend.
class PushNotificationService {
  PushNotificationService(this._api)
      : _localNotifications = LocalNotificationService(
          onNotificationTap: (data) {
            debugPrint('Local notification opened: $data');
          },
        );

  final ApiClient _api;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final LocalNotificationService _localNotifications;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _openedMessageSubscription;
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

    // iOS does not display notification payloads while the app is in the
    // foreground unless foreground presentation is explicitly enabled.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _localNotifications.initialize();

    // Keep the backend token mapping in sync with Supabase auth changes.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _registerCurrentToken(),
    );

    // FCM can rotate a token without restarting the app.
    _tokenSubscription = _messaging.onTokenRefresh.listen(_registerToken);

    // Android does not automatically present FCM notification payloads while
    // the app is foreground. Render the same server-originated message as a
    // native notification without creating another database notification.
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (message) async {
        final notification = message.notification;
        if (notification == null) return;

        await _localNotifications.showForegroundNotification(
          title: notification.title ?? 'ArenaHub',
          body: notification.body ?? '',
          data: message.data,
        );
      },
    );

    // Keep the tap payload available for deep-link integration. The
    // notification page remains the canonical in-app notification center.
    _openedMessageSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened: ${message.data}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from notification: ${initialMessage.data}');
    }

    await _registerCurrentToken();
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'ios';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'web';
    }
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
          'platform': _platformName(),
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
    await _foregroundMessageSubscription?.cancel();
    await _openedMessageSubscription?.cancel();
    await _localNotifications.dispose();
    _authSubscription = null;
    _tokenSubscription = null;
    _foregroundMessageSubscription = null;
    _openedMessageSubscription = null;
    _started = false;
  }
}
