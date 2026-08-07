import 'package:go_router/go_router.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/tournaments/presentation/home_page.dart';
import '../features/profile/presentation/profile_page.dart';

final appRouter = GoRouter(initialLocation: '/', routes: [
  GoRoute(path: '/', builder: (_, __) => const HomePage()),
  GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
  GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
]);
