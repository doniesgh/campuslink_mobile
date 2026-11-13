/// One change recorded in the audit log (`GET /admin/audit`).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.summary,
    required this.createdAt,
    this.actorName,
    this.actorEmail,
    this.targetType,
    this.targetId,
    this.ip,
    this.userAgent,
  });

  final String id;

  /// "area.verb", e.g. "user.update", "auth.password_reset".
  final String action;

  /// "Changed the role of Sarra Mansouri to Teacher"
  final String summary;

  /// Who did it, as they were at that moment (null for system actions).
  final String? actorName;
  final String? actorEmail;

  /// What [targetId] is: "user" (an account), or null for an entry about
  /// no one thing (an import).
  final String? targetType;

  /// The account the action was about.
  final String? targetId;
  final String? ip;

  /// The app or browser that made the request (null for older entries).
  final String? userAgent;
  final DateTime createdAt;

  /// The entry is about an account (that may have been deleted since).
  bool get isAboutUser => targetId != null && (targetType == null || targetType == 'user');
}

/// One page of the audit log, newest first.
class AuditPage {
  const AuditPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  final List<AuditEntry> items;
  final int total;
  final int page;
  final int limit;

  bool get hasMore => page * limit < total;
}
