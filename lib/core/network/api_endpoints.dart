/// Every backend path lives here. Never hardcode a path elsewhere.
abstract final class ApiEndpoints {
  // Auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refresh = '/auth/refresh';
  static const forgotPassword = '/auth/forgot-password';
  static const verifyEmail = '/auth/verify-email';
  static const me = '/users/me';

  // Forum (added per feature later)
  static const rides = '/rides';
  static String ride(String id) => '/rides/$id';
}
