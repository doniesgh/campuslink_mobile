import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_import.dart';
import '../../domain/import_assist.dart';

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

/// `{ total, byRole: { student, teacher, admin, alumni, company } }`
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

/// `GET /admin/users/import/assist`: `{ available, model }` (model null when off).
ImportAssistStatus importAssistStatusFromJson(Map<String, dynamic> json) => ImportAssistStatus(
      available: (json['available'] as bool?) ?? false,
      model: json['model'] as String?,
    );

/// `POST /admin/users/import/assist` body: `{ lines, values: [{ column, values }] }`.
Map<String, dynamic> assistRequestToJson(AssistRequest r) => {
      'lines': r.lines,
      'values': [
        for (final v in r.values) {'column': v.column, 'values': v.values},
      ],
    };

/// `{ mapping: { headerRow, columns: { lastName, firstName, fullName, email,
/// studentId, role, password }, nameOrder, roles: [{ text, role }] }, model }`.
/// Columns that are null or unknown are left out.
ImportAssistAnswer importAssistAnswerFromJson(Map<String, dynamic> json) {
  final mapping = json['mapping'] as Map<String, dynamic>;
  final columns = (mapping['columns'] as Map<String, dynamic>?) ?? const {};
  return ImportAssistAnswer(
    model: json['model'] as String,
    mapping: AssistMapping(
      headerRow: (mapping['headerRow'] as int?) ?? 0,
      columns: {
        for (final field in AssistField.values)
          if (columns[field.name] is int) field: columns[field.name] as int,
      },
      nameOrder: NameOrder.fromApi(mapping['nameOrder']),
      roles: [
        for (final r in (mapping['roles'] as List<dynamic>?) ?? const [])
          (text: (r as Map<String, dynamic>)['text'] as String, role: UserRole.fromName(r['role'])),
      ],
    ),
  );
}

/// `AuditEntry`:
/// ```json
/// { "id": "...", "action": "user.update", "summary": "...",
///   "actor": { "id": "...", "displayName": "Campus Admin", "email": "admin@campus.test" },
///   "targetType": "user", "targetId": "...", "metadata": {...}, "ip": "127.0.0.1",
///   "userAgent": "Dart/3.13 (dart:io)", "createdAt": "..." }
/// ```
/// `targetType` and `userAgent` are missing from older APIs (read as null).
AuditEntry auditEntryFromJson(Map<String, dynamic> json) {
  final actor = json['actor'] as Map<String, dynamic>?;
  return AuditEntry(
    id: json['id'] as String,
    action: json['action'] as String,
    summary: json['summary'] as String,
    actorName: actor?['displayName'] as String?,
    actorEmail: actor?['email'] as String?,
    targetType: json['targetType'] as String?,
    targetId: json['targetId'] as String?,
    ip: json['ip'] as String?,
    userAgent: json['userAgent'] as String?,
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
