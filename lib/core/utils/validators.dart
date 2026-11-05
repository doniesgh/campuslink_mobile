/// Form validators. Each returns an error message, or null when valid.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? notEmpty(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    return _email.hasMatch(v) ? null : 'Enter a valid email';
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Choose a password';
    return value.length < 8 ? 'Use at least 8 characters' : null;
  }

  /// Email verification code: exactly 6 digits.
  static String? code(String? value) {
    final v = value?.trim() ?? '';
    return RegExp(r'^\d{6}$').hasMatch(v) ? null : 'Enter the 6-digit code';
  }
}
