import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/profile/presentation/profile_setup_page.dart';
import '../features/registrations/presentation/registrations_page.dart';
import '../features/teams/presentation/screens/teams_list_screen.dart';
import '../features/teams/presentation/screens/team_invitations_screen.dart';
import '../features/tournaments/presentation/home_page.dart';
import '../features/tournaments/presentation/tournament_details_page.dart';
import '../features/tournaments/presentation/tournaments_page.dart';
import 'widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final location = state.matchedLocation;
    final isLogin = location == '/login';
    final isSplash = location == '/splash';

    if (session == null && !isLogin && !isSplash) return '/login';
    if (session != null && isLogin) return '/';
    return null;
  },
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomePage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(path: '/profile/setup', builder: (_, __) => const ProfileSetupPage()),
        GoRoute(path: '/teams', builder: (_, __) => const TeamsListScreen()),
        GoRoute(path: '/teams/invitations', builder: (_, __) => const TeamInvitationsScreen()),
        GoRoute(path: '/tournaments', builder: (_, __) => const TournamentsPage()),
        GoRoute(path: '/tournaments/:id', builder: (_, state) => TournamentDetailsPage(tournamentId: state.pathParameters['id']!)),
        GoRoute(path: '/registrations', builder: (_, __) => const RegistrationsPage()),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
      ],
    ),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((authState) {
      debugPrint('[APP ROUTER EVENT] ${authState.event} session=${authState.session != null}');
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
