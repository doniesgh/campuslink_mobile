import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/jobs/presentation/pages/my_applications_page.dart';
import '../../features/jobs/presentation/pages/job_applications_page.dart';
import '../../features/admin/presentation/pages/admin_users_page.dart';
import '../../features/admin/presentation/pages/audit_log_page.dart';
import '../../features/admin/presentation/pages/import_users_page.dart';
import '../../features/admin/presentation/pages/user_form_page.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/reset_password_page.dart';
import '../../features/auth/presentation/providers/auth_controller.dart';
import '../../features/carpooling/presentation/pages/new_ride_page.dart';
import '../../features/carpooling/presentation/pages/ride_detail_page.dart';
import '../../features/courses/presentation/pages/courses_page.dart';
import '../../features/forum/presentation/pages/forum_page.dart';
import '../../features/grades/presentation/pages/grades_page.dart';
import '../../features/jobs/presentation/pages/job_detail_page.dart';
import '../../features/jobs/presentation/pages/job_form_page.dart';
import '../../features/jobs/presentation/pages/jobs_page.dart';
import '../../features/timetable/presentation/admin/timetable_admin_page.dart';
import '../../features/timetable/presentation/pages/timetable_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'route_names.dart';
import 'shell_scaffold.dart';

/// Re-evaluates the router redirect whenever the auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

/// Where to send the user for [location] given the [auth] state, or null to stay.
/// Kept free of router/provider types so it can be unit-tested.
String? authRedirect(AsyncValue<User?> auth, String location) {
  if (auth.isLoading) return null; // restoring session
  final user = auth.valueOrNull;
  final inAuth = location.startsWith(RoutePaths.authPrefix);
  final inApp = location.startsWith(RoutePaths.appPrefix);

  if (user == null) return inApp ? RoutePaths.login : null;
  // Signed in: straight to the app. Sign-up needs no email verification, so
  // isEmailVerified is not checked (older unverified accounts get in too).
  if (inAuth) return RoutePaths.home;
  // Administration is for admins only (the API refuses everyone else too).
  final inAdmin = location == RoutePaths.adminPrefix ||
      location.startsWith('${RoutePaths.adminPrefix}/');
  if (inAdmin && !user.isAdmin) return RoutePaths.profile;
  // Admins, alumni and companies have no timetable or courses (the API refuses them too).
  final inTimetable = location == RoutePaths.timetable ||
      location.startsWith('${RoutePaths.timetable}/');
  if (inTimetable && !user.hasClasses) return RoutePaths.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: RoutePaths.login,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: RoutePaths.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: RoutePaths.register, builder: (_, __) => const RegisterPage()),
      GoRoute(path: RoutePaths.forgotPassword, builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(
        path: RoutePaths.resetPassword,
        builder: (_, state) =>
            ResetPasswordPage(email: state.uri.queryParameters['email'] ?? ''),
      ),
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
            GoRoute(
              path: RoutePaths.timetable,
              builder: (_, __) => const TimetablePage(),
              routes: [
                GoRoute(
                  path: 'courses',
                  builder: (_, state) =>
                      CoursesPage(initialCourseId: state.uri.queryParameters['course']),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.forum,
              builder: (_, __) => const ForumPage(),
              routes: [
                // Before 'rides/:rideId', or "new" would be read as a ride id.
                GoRoute(path: 'rides/new', builder: (_, __) => const NewRidePage()),
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
                // Before ':jobId', or "new" / "applications" would be read as an offer id.
                GoRoute(path: 'new', builder: (_, __) => const JobFormPage()),
                GoRoute(path: 'applications', builder: (_, __) => const MyApplicationsPage()),
                GoRoute(
                  path: ':jobId',
                  builder: (_, state) =>
                      JobDetailPage(jobId: state.pathParameters['jobId']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, state) =>
                          JobFormPage(jobId: state.pathParameters['jobId']),
                    ),
                    GoRoute(
                      path: 'applications',
                      builder: (_, state) =>
                          JobApplicationsPage(jobId: state.pathParameters['jobId']!),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          // StatefulShellBranch(routes: [
          //   GoRoute(
          //     path: RoutePaths.jobs,
          //     builder: (_, __) => const JobsPage(),
          //     routes: [
          //       // Before ':jobId', or "new" would be read as an offer id.
          //       GoRoute(path: 'new', builder: (_, __) => const JobFormPage()),
          //       GoRoute(
          //         path: ':jobId',
          //         builder: (_, state) =>
          //             JobDetailPage(jobId: state.pathParameters['jobId']!),
          //         routes: [
          //           GoRoute(
          //             path: 'edit',
          //             builder: (_, state) =>
          //                 JobFormPage(jobId: state.pathParameters['jobId']),
          //           ),
          //         ],
          //       ),
          //     ],
          //   ),
          // ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: RoutePaths.profile,
              builder: (_, __) => const ProfilePage(),
              routes: [
                GoRoute(path: 'grades', builder: (_, __) => const GradesPage()),
                GoRoute(
                  path: 'admin/users',
                  builder: (_, __) => const AdminUsersPage(),
                  routes: [
                    // Before ':userId', or "new" would be read as a user id.
                    GoRoute(path: 'new', builder: (_, __) => const UserFormPage()),
                    GoRoute(
                      path: ':userId',
                      builder: (_, state) =>
                          UserFormPage(userId: state.pathParameters['userId']!),
                    ),
                  ],
                ),
                GoRoute(path: 'admin/import', builder: (_, __) => const ImportUsersPage()),
                GoRoute(path: 'admin/audit', builder: (_, __) => const AuditLogPage()),
                GoRoute(path: 'admin/timetable', builder: (_, __) => const TimetableAdminPage()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
});
