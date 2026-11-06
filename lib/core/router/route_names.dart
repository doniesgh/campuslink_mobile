/// All route paths in one place. No string literals in pages.
abstract final class RoutePaths {
  /// Also the onboarding screen: signed-out users land here.
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const verifyEmail = '/auth/verify-email';

  /// Reset screen for [email] (the code was emailed to it).
  static String resetPasswordFor(String email) =>
      Uri(path: resetPassword, queryParameters: {'email': email}).toString();

  static const home = '/app/home';
  static const timetable = '/app/timetable';
  static const forum = '/app/forum';
  static const jobs = '/app/jobs';
  static const profile = '/app/profile';
  static const notifications = '/app/notifications';

  /// Pushed inside their tab, so the bottom bar stays visible.
  static const courses = '$timetable/courses';
  static const grades = '$profile/grades';

  /// Courses screen opened on [course] (a course id or title).
  static String coursesFor(String course) =>
      Uri(path: courses, queryParameters: {'course': course}).toString();

  /// "Proposer un trajet" form.
  static const newRide = '$forum/rides/new';
  static String ride(String id) => '$forum/rides/$id';
  static String job(String id) => '$jobs/$id';

  static const authPrefix = '/auth';
  static const appPrefix = '/app';
}
