/// Every backend path lives here. Never hardcode a path elsewhere.
/// The backend is in backend/ (see backend/README.md for the full contract).
abstract final class ApiEndpoints {
  // Auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const verifyEmail = '/auth/verify-email';
  static const me = '/users/me';

  // Timetable (query: ?date=YYYY-MM-DD)
  static const timetableDay = '/timetable/day';
  static const timetableWeek = '/timetable/week';

  // Courses
  static const courses = '/courses';
  static String courseAttendance(String courseId) => '/courses/$courseId/attendance';
  static String courseResourceDownload(String resourceId) =>
      '/courses/resources/$resourceId/download';
  static String courseAssignmentSubmission(String assignmentId) =>
      '/courses/assignments/$assignmentId/submission';

  // Carpooling (POST on rides publishes a ride)
  static const rides = '/carpool/rides';
  static String ride(String id) => '/carpool/rides/$id';
  static String rideReservations(String id) => '/carpool/rides/$id/reservations';
  static const carpoolImpact = '/carpool/impact';

  // Jobs
  static const jobs = '/jobs';
  static String job(String id) => '/jobs/$id';
  static String jobApplications(String id) => '/jobs/$id/applications';

  // Forum (POST on lostItems publishes a notice, POST on ideas publishes an idea)
  static const forumHighlights = '/forum/highlights';
  static const lostItems = '/forum/lost-items';
  static String lostItemRequests(String id) => '/forum/lost-items/$id/requests';
  static const ideas = '/forum/ideas';
  static String ideaUpvote(String id) => '/forum/ideas/$id/upvote';

  // Grades
  static const transcript = '/grades/transcript';

  // Profile
  static const profile = '/profile';

  // Notifications
  static const notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const notificationsReadAll = '/notifications/read-all';

  // Push notifications
  static const pushDevices = '/push/devices';

  // Admin (admins only: the API answers 403 to everyone else)
  static const adminUsers = '/admin/users';
  static const adminUserStats = '/admin/users/stats';
  static const adminUserImport = '/admin/users/import';
  static String adminUser(String id) => '/admin/users/$id';
  static const adminAudit = '/admin/audit';
  static const adminAuditActions = '/admin/audit/actions';
}
