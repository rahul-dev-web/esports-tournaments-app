import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/teams/presentation/screens/teams_list_screen.dart';
import '../features/teams/presentation/screens/team_invitations_screen.dart';
import '../features/tournaments/presentation/home_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLogin = state.matchedLocation == '/login';

    if (session == null && !isLogin) return '/login';
    if (session != null && isLogin) return '/';

    return null;
  },
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/teams', builder: (_, __) => const TeamsListScreen()),
    GoRoute(path: '/teams/invitations', builder: (_, __) => const TeamInvitationsScreen()),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
