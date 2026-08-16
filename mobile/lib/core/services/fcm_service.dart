import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

class FcmService {
  Future<String?> getToken() async {
    if (kIsWeb) return FirebaseMessaging.instance.getToken();
    return FirebaseMessaging.instance.getToken();
  }

  Stream<String?> onTokenRefresh() => FirebaseMessaging.instance.onTokenRefresh;

  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission();
  }

  Future<void> registerCurrentToken(ApiClient api) async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) return;

    final platform = kIsWeb ? 'web' : Platform.operatingSystem;
    await api.post(
      '/notifications/device-tokens',
      body: {
        'token': token,
        'platform': platform,
      },
    );
  }
}
