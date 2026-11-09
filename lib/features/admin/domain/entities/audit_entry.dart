/// One change recorded in the audit log (`GET /admin/audit`).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.summary,
    required this.createdAt,
    this.actorName,
    this.actorEmail,
    this.targetId,
    this.ip,
  });

  final String id;

  /// "area.verb", e.g. "user.update".
  final String action;

  /// "Changed the role of Sarra Mansouri to Teacher"
  final String summary;

  /// Who did it, as they were at that moment (null for system actions).
  final String? actorName;
  final String? actorEmail;

  /// The account the action was about.
  final String? targetId;
  final String? ip;
  final DateTime createdAt;
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
