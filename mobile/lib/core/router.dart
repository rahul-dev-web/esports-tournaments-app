import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/registrations/presentation/registrations_page.dart';
import '../features/teams/presentation/screens/teams_list_screen.dart';
import '../features/teams/presentation/screens/team_invitations_screen.dart';
import '../features/tournaments/presentation/home_page.dart';
import '../features/tournaments/presentation/tournament_details_page.dart';
import '../features/tournaments/presentation/tournaments_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLogin = state.matchedLocation == '/login';

    debugPrint('[APP ROUTER 01] redirect() called');
    debugPrint('[APP ROUTER 02] URI: ${Uri.base}');
    debugPrint('[APP ROUTER 03] matchedLocation: ${state.matchedLocation}');
    debugPrint('[APP ROUTER 04] fullPath: ${state.fullPath}');
    debugPrint('[APP ROUTER 05] session: ${session != null ? 'FOUND' : 'NULL'}');
    debugPrint('[APP ROUTER 06] isLogin: $isLogin');

    if (session == null && !isLogin) {
      debugPrint('[APP ROUTER 07] Redirecting -> /login because session is NULL');
      return '/login';
    }

    if (session != null && isLogin) {
      debugPrint('[APP ROUTER 08] Redirecting -> / because session is FOUND');
      return '/';
    }

    debugPrint('[APP ROUTER 09] No redirect');
    return null;
  },
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
    GoRoute(path: '/teams', builder: (_, __) => const TeamsListScreen()),
    GoRoute(path: '/teams/invitations', builder: (_, __) => const TeamInvitationsScreen()),
    GoRoute(path: '/tournaments', builder: (_, __) => const TournamentsPage()),
    GoRoute(path: '/tournaments/:id', builder: (_, state) => TournamentDetailsPage(tournamentId: state.pathParameters['id']!)),
    GoRoute(path: '/registrations', builder: (_, __) => const RegistrationsPage()),
  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((authState) {
      debugPrint('[APP ROUTER EVENT 01] Router auth stream event: ${authState.event}');
      debugPrint('[APP ROUTER EVENT 02] Session: ${authState.session != null ? 'FOUND' : 'NULL'}');
      debugPrint('[APP ROUTER EVENT 03] URI: ${Uri.base}');
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
