import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Displays foreground FCM messages as native notifications on platforms
/// where Firebase does not automatically present notification payloads.
class LocalNotificationService {
  LocalNotificationService({this.onNotificationTap});

  final void Function(Map<String, dynamic> data)? onNotificationTap;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'arenahub_notifications';
  static const String _channelName = 'ArenaHub Notifications';
  static const String _channelDescription =
      'Tournament, team, registration and account notifications.';

  bool _initialized = false;
  int _nextId = 1000;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            onNotificationTap?.call(Map<String, dynamic>.from(decoded));
          }
        } catch (error) {
          debugPrint('Invalid local notification payload: $error');
        }
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> showForegroundNotification({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    if (!_initialized || kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ArenaHub notification',
    );

    await _plugin.show(
      _nextId++,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: jsonEncode(data),
    );
  }

  Future<void> dispose() async {
    await _plugin.cancelAll();
    _initialized = false;
  }
}
