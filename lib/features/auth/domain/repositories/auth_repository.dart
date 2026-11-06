import '../../../../core/error/result.dart';
import '../entities/user.dart';

/// Contract used by presentation. Implemented in the data layer.
abstract interface class AuthRepository {
  /// [identifier] is the student's ENT ID or email.
  Future<Result<User>> login({required String identifier, required String password});
  Future<Result<User>> register({
    required String displayName,
    required String email,
    required String password,
  });
  Future<Result<void>> forgotPassword(String email);
  Future<Result<void>> resetPassword({
    required String email,
    required String code,
    required String password,
  });
  Future<Result<User>> verifyEmail(String code);

  /// Returns the current user if a valid session exists, otherwise null.
  Future<Result<User?>> restoreSession();
  Future<void> logout();
}
