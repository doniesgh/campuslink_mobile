import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/auth_pages.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/carpooling/presentation/pages/ride_detail_page.dart';
import '../../features/forum/presentation/pages/forum_page.dart';
import '../../features/jobs/presentation/pages/job_detail_page.dart';
import '../../features/jobs/presentation/pages/jobs_page.dart';
import '../../features/timetable/presentation/pages/timetable_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/welcome/presentation/pages/welcome_page.dart';
import 'route_names.dart';
import 'shell_scaffold.dart';

/// Re-evaluates the router redirect whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return null; // restoring session
      final user = auth.valueOrNull;
      final loc = state.matchedLocation;
      final inAuth = loc.startsWith(RoutePaths.authPrefix);
      final inApp = loc.startsWith(RoutePaths.appPrefix);

      if (user == null) return inApp ? RoutePaths.welcome : null;
      if (!user.isEmailVerified) {
        return loc == RoutePaths.verifyEmail ? null : RoutePaths.verifyEmail;
      }
      if (inAuth || loc == RoutePaths.welcome) return RoutePaths.home;
      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.welcome, builder: (_, __) => const WelcomePage()),
      GoRoute(path: RoutePaths.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: RoutePaths.register, builder: (_, __) => const RegisterPage()),
      GoRoute(path: RoutePaths.forgotPassword, builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: RoutePaths.verifyEmail, builder: (_, __) => const VerifyEmailPage()),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (_, __) => const NotificationsPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellScaffold(shell: shell),
        // Order MUST match the tabs in shell_scaffold.dart.
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.home, builder: (_, __) => const HomePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.timetable, builder: (_, __) => const TimetablePage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.forum,
              builder: (_, __) => const ForumPage(),
              routes: [
                GoRoute(
                  path: 'rides/:rideId',
                  builder: (_, state) =>
                      RideDetailPage(rideId: state.pathParameters['rideId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.jobs,
              builder: (_, __) => const JobsPage(),
              routes: [
                GoRoute(
                  path: ':jobId',
                  builder: (_, state) =>
                      JobDetailPage(jobId: state.pathParameters['jobId']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.profile, builder: (_, __) => const ProfilePage()),
          ]),
        ],
      ),
    ],
  );
});
