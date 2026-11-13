/// What a user is on campus. Sign-up always gives [student]; only an admin
/// can change a role. Names match the API's `role` values.
enum UserRole {
  student('Student'),
  teacher('Teacher'),
  admin('Admin'),
  alumni('Alumni'),

  /// A recruiter (a partner company): posts job offers.
  company('Company');

  const UserRole(this.label);

  /// "Student", "Teacher", "Admin", "Alumni", "Company".
  final String label;

  /// Follows classes, so has a timetable and courses. Admins run the platform,
  /// alumni have graduated and companies recruit: the API refuses them (403).
  bool get hasClasses => this == student || this == teacher;

  /// The role named [name] by the API, or null for a value this app doesn't know.
  static UserRole? fromName(Object? name) {
    for (final role in values) {
      if (role.name == name) return role;
    }
    return null;
  }
}

/// Domain entity: independent from JSON / Mongo field names.
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isEmailVerified = false,
    this.role = UserRole.student,
    this.locale = 'fr',
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isEmailVerified;
  final UserRole role;

  /// The account's language ("fr" or "en"): the server writes this user's
  /// emails and notifications in it. The app keeps it equal to the language
  /// on screen (see `AuthController.syncLanguage`).
  final String locale;

  /// Can open the Administration screens (the API checks again on every call).
  bool get isAdmin => role == UserRole.admin;

  /// Has the Timetable tab and its courses (see [UserRole.hasClasses]).
  bool get hasClasses => role.hasClasses;

  User copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    bool? isEmailVerified,
    UserRole? role,
    String? locale,
  }) =>
      User(
        id: id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        role: role ?? this.role,
        locale: locale ?? this.locale,
      );
}
