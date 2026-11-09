import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_import.dart';

/// JSON of the `/admin` API (docs/api.md, "Admin"). A missing or unknown
/// role reads as student.

/// `ManagedUser`:
/// ```json
/// { "id": "...", "email": "...", "studentId": "211JMT0428", "displayName": "...",
///   "role": "student", "isEmailVerified": true, "createdAt": "2026-11-05T09:15:00.000Z" }
/// ```
ManagedUser managedUserFromJson(Map<String, dynamic> json) => ManagedUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: UserRole.fromName(json['role']) ?? UserRole.student,
      studentId: json['studentId'] as String?,
      isEmailVerified: (json['isEmailVerified'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );

/// `{ items, total, page, limit }`
UserPage userPageFromJson(Map<String, dynamic> json) => UserPage(
      items: [
        for (final item in json['items'] as List<dynamic>)
          managedUserFromJson(item as Map<String, dynamic>),
      ],
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );

/// `{ total, byRole: { student, teacher, admin, alumni } }`
UserStats userStatsFromJson(Map<String, dynamic> json) {
  final byRole = json['byRole'] as Map<String, dynamic>;
  return UserStats(
    total: json['total'] as int,
    byRole: {
      for (final role in UserRole.values) role: (byRole[role.name] as int?) ?? 0,
    },
  );
}

Map<String, dynamic> newUserToJson(NewUser user) {
  final studentId = user.studentId?.trim() ?? '';
  return {
    'displayName': user.displayName.trim(),
    'email': user.email.trim().toLowerCase(),
    'password': user.password,
    'role': user.role.name,
    if (studentId.isNotEmpty) 'studentId': studentId.toUpperCase(),
  };
}

/// Only the changed fields. An empty `studentId` is sent as null (removes it).
Map<String, dynamic> userChangesToJson(UserChanges c) => {
      if (c.displayName != null) 'displayName': c.displayName,
      if (c.email != null) 'email': c.email,
      if (c.studentId != null) 'studentId': c.studentId!.isEmpty ? null : c.studentId,
      if (c.role != null) 'role': c.role!.name,
      if (c.password != null) 'password': c.password,
      if (c.isEmailVerified != null) 'isEmailVerified': c.isEmailVerified,
    };

Map<String, dynamic> importRowToJson(ImportRow r) => {
      'row': r.row,
      'displayName': r.displayName,
      'email': r.email,
      'password': r.password,
      if (r.role != null) 'role': r.role!.name,
      if (r.studentId != null) 'studentId': r.studentId,
    };

/// `{ row, field, code, message }`
ImportProblem importProblemFromJson(Map<String, dynamic> json) => ImportProblem(
      row: json['row'] as int,
      field: json['field'] as String,
      code: json['code'] as String,
      message: json['message'] as String,
    );

List<ImportProblem> importProblemsFromJson(Object? json) => [
      for (final p in (json as List<dynamic>?) ?? const [])
        importProblemFromJson(p as Map<String, dynamic>),
    ];

/// Dry run: `{ dryRun: true, valid, problems }`
ImportCheck importCheckFromJson(Map<String, dynamic> json) => ImportCheck(
      valid: json['valid'] as int,
      problems: importProblemsFromJson(json['problems']),
    );

/// `AuditEntry`:
/// ```json
/// { "id": "...", "action": "user.update", "summary": "...",
///   "actor": { "id": "...", "displayName": "Campus Admin", "email": "admin@campus.test" },
///   "targetId": "...", "metadata": {...}, "ip": "127.0.0.1", "createdAt": "..." }
/// ```
AuditEntry auditEntryFromJson(Map<String, dynamic> json) {
  final actor = json['actor'] as Map<String, dynamic>?;
  return AuditEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    summary: json['summary'] as String,
    actorName: actor?['displayName'] as String?,
    actorEmail: actor?['email'] as String?,
    targetId: json['targetId'] as String?,
    ip: json['ip'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}

AuditPage auditPageFromJson(Map<String, dynamic> json) => AuditPage(
      items: [
        for (final item in json['items'] as List<dynamic>)
          auditEntryFromJson(item as Map<String, dynamic>),
      ],
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
