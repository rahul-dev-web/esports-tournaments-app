import 'package:firebase_messaging/firebase_messaging.dart';

class FcmService {
  Future<String?> getToken() async {
    return FirebaseMessaging.instance.getToken();
  }

  Stream<String?> onTokenRefresh() {
    return FirebaseMessaging.instance.onTokenRefresh;
  }

  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission();
  }
}
