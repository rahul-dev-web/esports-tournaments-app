import 'dart:async';

import 'package:flutter/foundation.dart';
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
    debugPrint('[AUTH_DEBUG] AuthController.build() started');

    ref.onDispose(() {
      debugPrint('[AUTH_DEBUG] AuthController disposed; cancelling auth subscription');
      _subscription?.cancel();
    });

    final session = _supabase.auth.currentSession;
    debugPrint('[AUTH_DEBUG] currentSessionAtBuild=${session != null}');

    _subscription = _supabase.auth.onAuthStateChange.listen((authState) {
      debugPrint(
        '[AUTH_DEBUG] SUPABASE AUTH EVENT: event=${authState.event.name}, session=${authState.session != null}',
      );
      debugPrint('[AUTH_DEBUG] auth user present=${authState.session?.user != null}');
      unawaited(refresh());
    });

    if (session == null) return null;

    debugPrint('[AUTH_DEBUG] Existing session found; loading /auth/me');
    return _loadProfile();
  }

  Future<UserProfile?> _loadProfile() async {
    debugPrint('[AUTH_DEBUG] _loadProfile() -> GET /auth/me');
    try {
      final response = await _api.get('/auth/me');
      debugPrint('[AUTH_DEBUG] /auth/me SUCCESS');
      return UserProfile.fromJson(response);
    } on ApiException catch (error) {
      debugPrint('[AUTH_DEBUG] /auth/me FAILED: status=${error.statusCode}, error=$error');
      if (error.statusCode == 401 || error.statusCode == 403) {
        debugPrint('[AUTH_DEBUG] /auth/me returned ${error.statusCode}; signing out Supabase session');
        await _supabase.auth.signOut();
      }
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[AUTH_DEBUG] /auth/me unexpected error=$error');
      debugPrint('[AUTH_DEBUG] STACK: $stackTrace');
      rethrow;
    }
  }

  Future<void> refresh() async {
    final session = _supabase.auth.currentSession;
    debugPrint('[AUTH_DEBUG] refresh() called; session=${session != null}');

    if (session == null) {
      debugPrint('[AUTH_DEBUG] refresh(): no session -> AsyncData(null)');
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadProfile);
    debugPrint('[AUTH_DEBUG] refresh() completed; state=${state.runtimeType}');
  }

  Future<void> signOut() async {
    debugPrint('[AUTH_DEBUG] signOut() called');
    state = const AsyncLoading();
    try {
      await _supabase.auth.signOut();
      debugPrint('[AUTH_DEBUG] signOut() SUCCESS');
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      debugPrint('[AUTH_DEBUG] signOut() FAILED: $error');
      debugPrint('[AUTH_DEBUG] STACK: $stackTrace');
      state = AsyncError(error, stackTrace);
    }
  }
}
