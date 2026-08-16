import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../router.dart';
import 'api_client.dart';
import 'local_notification_service.dart';

/// Owns the mobile FCM lifecycle.
///
/// The backend is the source of truth for notification records and device
/// targeting. This service handles Firebase permission/token lifecycle and
/// synchronises the current device token with the backend.
class PushNotificationService {
  PushNotificationService(this._api)
      : _localNotifications = LocalNotificationService();

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

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _localNotifications.onNotificationTap = _handleNotificationTap;
    await _localNotifications.initialize();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _registerCurrentToken(),
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen(_registerToken);

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

    _openedMessageSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(
        Duration.zero,
        () => _handleNotificationTap(initialMessage.data),
      );
    }

    await _registerCurrentToken();
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    _handleNotificationTap(message.data);
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    unawaited(_processNotificationTap(data));
  }

  Future<void> _processNotificationTap(Map<String, dynamic> rawData) async {
    final data = Map<String, dynamic>.from(rawData);
    final notificationId = data['notification_id']?.toString();

    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        await _api.patch('/notifications/$notificationId/read');
      } catch (error) {
        // Navigation must remain available even when marking the notification
        // read temporarily fails because of network/authentication state.
        debugPrint('Unable to mark notification as read: $error');
      }
    }

    final tournamentId = data['tournament_id']?.toString();
    final teamId = data['team_id']?.toString();
    final type = data['type']?.toString() ?? data['notification_type']?.toString();

    if (tournamentId != null && tournamentId.isNotEmpty) {
      appRouter.go('/tournaments/${Uri.encodeComponent(tournamentId)}');
      return;
    }

    if (type != null &&
        (type.contains('invitation') || type.contains('team_invitation'))) {
      appRouter.go('/teams/invitations');
      return;
    }

    if (teamId != null && teamId.isNotEmpty) {
      appRouter.go('/teams');
      return;
    }

    if (type != null && type.contains('registration')) {
      appRouter.go('/registrations');
      return;
    }

    appRouter.go('/notifications');
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
