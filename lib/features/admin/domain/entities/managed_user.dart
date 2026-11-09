import '../../../auth/domain/entities/user.dart';

/// An account as an admin sees it in the Users screens.
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.studentId,
    this.isEmailVerified = true,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;

  /// ENT ID (e.g. 211JMT0428), null when the school hasn't assigned one.
  final String? studentId;
  final bool isEmailVerified;
  final DateTime createdAt;

  ManagedUser copyWith({
    String? email,
    String? displayName,
    UserRole? role,
    String? Function()? studentId,
    bool? isEmailVerified,
  }) =>
      ManagedUser(
        id: id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        studentId: studentId == null ? this.studentId : studentId(),
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        createdAt: createdAt,
      );
}

/// One page of `GET /admin/users`.
class UserPage {
  const UserPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<ManagedUser> items;

  /// Matching accounts on every page.
  final int total;

  /// 1-based.
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}

/// How many accounts there are, in all and per role.
class UserStats {
  const UserStats({required this.total, required this.byRole});

  final int total;
  final Map<UserRole, int> byRole;

  int count(UserRole role) => byRole[role] ?? 0;
}

/// A new account, created by an admin.
class NewUser {
  const NewUser({
    required this.displayName,
    required this.email,
    required this.password,
    this.role = UserRole.student,
    this.studentId,
  });

  final String displayName;
  final String email;
  final String password;
  final UserRole role;

  /// Null or empty: no ENT ID.
  final String? studentId;
}

/// The fields an admin changes on an account. Null fields are left as they are.
class UserChanges {
  const UserChanges({
    this.displayName,
    this.email,
    this.studentId,
    this.role,
    this.password,
    this.isEmailVerified,
  });

  final String? displayName;
  final String? email;

  /// The new ENT ID. An empty string removes it.
  final String? studentId;
  final UserRole? role;

  /// A new password. The user is signed out on every device.
  final String? password;
  final bool? isEmailVerified;

  bool get isEmpty =>
      displayName == null &&
      email == null &&
      studentId == null &&
      role == null &&
      password == null &&
      isEmailVerified == null;

  /// The changes between [before] and the form's values: only what differs.
  /// An empty [password] means "keep the current one".
  factory UserChanges.between(
    ManagedUser before, {
    required String displayName,
    required String email,
    required String studentId,
    required UserRole role,
    required String password,
    required bool isEmailVerified,
  }) {
    final newStudentId = studentId.trim().toUpperCase();
    return UserChanges(
      displayName: displayName.trim() == before.displayName ? null : displayName.trim(),
      email: email.trim().toLowerCase() == before.email ? null : email.trim().toLowerCase(),
      studentId: newStudentId == (before.studentId ?? '') ? null : newStudentId,
      role: role == before.role ? null : role,
      password: password.isEmpty ? null : password,
      isEmailVerified: isEmailVerified == before.isEmailVerified ? null : isEmailVerified,
    );
  }
}
