import '../../../auth/domain/entities/user.dart';
import 'managed_user.dart';

/// One account to create, read from a line of the admin's file.
class ImportRow {
  const ImportRow({
    required this.row,
    required this.displayName,
    required this.email,
    required this.password,
    this.role,
    this.studentId,
    this.passwordGenerated = false,
  });

  /// Line number in the file, echoed back by the server in its problems.
  final int row;
  final String displayName;
  final String email;
  final String password;

  /// Null when the role cell couldn't be read (the line then has a problem).
  final UserRole? role;
  final String? studentId;

  /// The file had no password for this line: the app made one up, and the
  /// admin must pass it on (see the sign-in details at the end).
  final bool passwordGenerated;
}

/// Why a line can't be imported. [code] and [message] follow the API
/// (`REQUIRED`, `INVALID_EMAIL`, `EMAIL_TAKEN`...).
class ImportProblem {
  const ImportProblem({
    required this.row,
    required this.field,
    required this.code,
    required this.message,
  });

  final int row;
  final String field;
  final String code;

  /// "Email: an account already uses it"
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ImportProblem &&
      other.row == row &&
      other.field == field &&
      other.code == code;

  @override
  int get hashCode => Object.hash(row, field, code);
}

/// The server's dry run: how many lines are fine, and the problems of the others.
class ImportCheck {
  const ImportCheck({required this.valid, required this.problems});

  final int valid;
  final List<ImportProblem> problems;
}

/// What a real import gave.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// Every account of the batch was created.
class ImportCreated extends ImportOutcome {
  const ImportCreated(this.users);

  final List<ManagedUser> users;
}

/// The server found problems, so nothing of the batch was created.
class ImportRefused extends ImportOutcome {
  const ImportRefused(this.message, this.problems);

  final String message;
  final List<ImportProblem> problems;
}
