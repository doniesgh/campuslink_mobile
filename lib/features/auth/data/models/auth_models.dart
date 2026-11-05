import '../../domain/entities/user.dart';

/// Expected backend user JSON (Mongo `_id` or `id` both accepted):
/// { "_id": "...", "email": "...", "displayName": "...", "avatarUrl": null, "isEmailVerified": true }
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.isEmailVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: (json['id'] ?? json['_id']).toString(),
        email: json['email'] as String,
        displayName: (json['displayName'] ?? json['name'] ?? '') as String,
        avatarUrl: json['avatarUrl'] as String?,
        isEmailVerified: (json['isEmailVerified'] as bool?) ?? false,
      );

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final bool isEmailVerified;

  User toEntity() => User(
        id: id,
        email: email,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isEmailVerified: isEmailVerified,
      );
}

/// Expected login/register response:
/// { "user": {...}, "accessToken": "...", "refreshToken": "..." }
class AuthResponseModel {
  const AuthResponseModel({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthResponseModel(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final UserModel user;
  final String accessToken;
  final String refreshToken;
}
