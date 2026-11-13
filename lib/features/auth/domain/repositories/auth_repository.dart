import '../../../../core/error/result.dart';
import '../entities/user.dart';

/// Contract used by presentation. Implemented in the data layer.
abstract interface class AuthRepository {
  /// [identifier] is the student's ENT ID or email.
  Future<Result<User>> login({required String identifier, required String password});
  /// [locale] ("fr" or "en") becomes the account's language.
  Future<Result<User>> register({
    required String displayName,
    required String email,
    required String password,
    String? locale,
  });
  Future<Result<void>> forgotPassword(String email);
  Future<Result<void>> resetPassword({
    required String email,
    required String code,
    required String password,
  });

  /// Returns the current user if a valid session exists, otherwise null.
  Future<Result<User?>> restoreSession();

  /// Changes the signed-in account's own settings (`PATCH /users/me`): only
  /// the arguments given. Returns the updated account.
  Future<Result<User>> updateMe({String? locale});

  /// Signs out. [pushToken] is this phone's push token, if it registered one:
  /// the server then stops sending push notifications to it.
  Future<void> logout({String? pushToken});
}
