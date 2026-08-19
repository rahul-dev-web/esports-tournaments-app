import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authProvider = AsyncNotifierProvider<AuthController, UserProfile?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<UserProfile?> {
  StreamSubscription<AuthState>? _subscription;

  SupabaseClient get _supabase => Supabase.instance.client;
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  FutureOr<UserProfile?> build() async {
    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Subscribe even when there is no session yet. The OAuth flow starts with
    // a null session and establishes the session later when the deep-link
    // callback returns to the app.
    _subscription = _supabase.auth.onAuthStateChange.listen((authState) {
      debugPrint('[APP AUTH PROVIDER] Event: ${authState.event}');
      debugPrint('[APP AUTH PROVIDER] Session: ${authState.session != null ? 'FOUND' : 'NULL'}');

      // The initial session is already handled below. All later auth events
      // must refresh the profile, including SIGNED_IN after OAuth callback.
      if (authState.event != AuthChangeEvent.initialSession) {
        unawaited(refresh());
      }
    });

    final session = _supabase.auth.currentSession;
    if (session == null) return null;

    return _loadProfile();
  }

  Future<UserProfile?> _loadProfile() async {
    try {
      final response = await _api.get('/auth/me');
      return UserProfile.fromJson(response);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _supabase.auth.signOut();
      }
      rethrow;
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
    state = const AsyncLoading();
    try {
      await _supabase.auth.signOut();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}
