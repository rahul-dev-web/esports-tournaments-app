import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseAuthStateProvider = StreamProvider<AuthState>(
  (ref) => Supabase.instance.client.auth.onAuthStateChange,
);

final currentSessionProvider = Provider<Session?>(
  (ref) {
    ref.watch(supabaseAuthStateProvider);
    return Supabase.instance.client.auth.currentSession;
  },
);

final currentAccessTokenProvider = Provider<String?>(
  (ref) {
    final session = ref.watch(currentSessionProvider);
    return session?.accessToken;
  },
);

final currentUserIdProvider = Provider<String?>(
  (ref) {
    ref.watch(supabaseAuthStateProvider);
    return Supabase.instance.client.auth.currentUser?.id;
  },
);
