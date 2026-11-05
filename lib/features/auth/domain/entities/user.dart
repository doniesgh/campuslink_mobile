/// Domain entity: independent from JSON / Mongo field names.
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isEmailVerified = false,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isEmailVerified;
}
