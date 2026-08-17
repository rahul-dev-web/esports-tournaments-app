import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/fcm_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final fcmServiceProvider = Provider<FcmService>((ref) => FcmService());

final authProvider = AsyncNotifierProvider<AuthController, UserProfile?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<UserProfile?> {
  StreamSubscription<AuthState>? _subscription;
  StreamSubscription<String>? _tokenSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;
  ApiClient get _api => ref.read(apiClientProvider);
  FcmService get _fcm => ref.read(fcmServiceProvider);

  @override
  FutureOr<UserProfile?> build() async {
    ref.onDispose(() {
      _subscription?.cancel();
      _tokenSubscription?.cancel();
    });

    // Supabase is initialized by main.dart only when the required build-time
    // configuration is present. If it has no usable configuration, there is
    // no authenticated session to restore.
    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    _subscription = _supabase.auth.onAuthStateChange.listen((_) {
      unawaited(refresh());
    });

    return _loadProfile();
  }

  Future<UserProfile?> _loadProfile() async {
    try {
      final response = await _api.get('/auth/me');
      final profile = UserProfile.fromJson(response);
      unawaited(_registerFcmToken());
      return profile;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _supabase.auth.signOut();
      }
      rethrow;
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      await _fcm.requestPermission();
      await _fcm.registerCurrentToken(_api);
      await _tokenSubscription?.cancel();
      _tokenSubscription = _fcm.onTokenRefresh().listen((_) {
        unawaited(_fcm.registerCurrentToken(_api));
      });
    } catch (_) {
      // Notification registration must never block authentication.
    }
  }

  Future<void> refresh() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadProfile);
  }

  Future<void> signOut() async {
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
    state = const AsyncLoading();
    await _supabase.auth.signOut();
    state = const AsyncData(null);
  }
}
