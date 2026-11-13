/// All route paths in one place. No string literals in pages.
abstract final class RoutePaths {
  /// Also the onboarding screen: signed-out users land here.
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';

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

  /// Offer form (companies and admins): post a new offer, or edit offer [id].
  static const newJob = '$jobs/new';
  static String editJob(String id) => '$jobs/$id/edit';
  static const myApplications = '$jobs/applications';
  static String jobApplications(String id) => '${job(id)}/applications';

  /// Administration, inside the Profile tab. Admins only: [authRedirect]
  /// sends everyone else back to Profile (and the API refuses them anyway).
  static const adminPrefix = '$profile/admin';
  static const adminUsers = '$adminPrefix/users';
  static const newUser = '$adminUsers/new';
  static String adminUser(String id) => '$adminUsers/$id';
  static const importUsers = '$adminPrefix/import';
  static const auditLog = '$adminPrefix/audit';
  static const adminTimetable = '$adminPrefix/timetable';

  static const authPrefix = '/auth';
  static const appPrefix = '/app';
}
