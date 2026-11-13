import '../../../../core/error/failures.dart';
import '../../../../core/error/result.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/entities/managed_user.dart';
import '../../domain/entities/user_import.dart';
import '../../domain/import_assist.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/search_text.dart';
import '../../domain/user_import_parser.dart';

/// In-memory stand-in for `/admin/*` (USE_MOCK=true). Same accounts as the
/// backend seed, and the same rules and messages as the API, so the screens
/// behave the same offline.
class MockAdminRepository implements AdminRepository {
  MockAdminRepository({
    String? Function()? currentUserId,
    DateTime Function()? now,
    this.delay = const Duration(milliseconds: 400),
    this.assistAvailable = true,
  })  : _currentUserId = currentUserId ?? (() => MockAuthRemoteDataSource.adminId),
        _now = now ?? DateTime.now {
    final created = _now().subtract(const Duration(days: 30));
    for (final (i, (id, name, email, studentId, role, verified)) in _demoAccounts.indexed) {
      _users[id] = ManagedUser(
        id: id,
        email: email,
        displayName: name,
        role: role,
        studentId: studentId,
        isEmailVerified: verified,
        createdAt: created.add(Duration(hours: i)),
      );
    }
  }

  final String? Function() _currentUserId;
  final DateTime Function() _now;
  final Duration delay;

  /// Whether "Read with AI" is offered (the server has an AI key).
  final bool assistAvailable;

  /// When set, [assistImport] fails with it (tests: busy, not available...).
  Failure? assistFailure;

  /// The model the mock AI answers as.
  static const assistModel = 'mock/import-assist';

  final _users = <String, ManagedUser>{};
  final _audit = <AuditEntry>[];
  var _nextId = 1;

  static const _demoAccounts = [
    (MockAuthRemoteDataSource.adminId, 'Campus Admin', 'admin@campus.test', null, UserRole.admin, true),
    ('mock-1', 'Dony Mansour', 'dony.mansour@campus.test', '211JMT0428', UserRole.student, true),
    ('u-amira', 'Amira Ben Salah', 'amira.bensalah@campus.test', null, UserRole.teacher, true),
    ('u-karim', 'Karim Trabelsi', 'karim.trabelsi@campus.test', null, UserRole.teacher, true),
    ('u-sarra', 'Sarra Mansouri', 'sarra.mansouri@campus.test', '221JMT0101', UserRole.student, true),
    ('u-omar', 'Omar Ferchichi', 'omar.ferchichi@campus.test', '221JMT0102', UserRole.student, true),
    ('u-yasmine', 'Yasmine Haddad', 'yasmine.haddad@campus.test', '221JMT0103', UserRole.student, true),
    ('u-ines', 'Inès Zouari', 'ines.zouari@campus.test', '221JMT0104', UserRole.student, true),
    ('u-youssef', 'Youssef Hammami', 'youssef.hammami@campus.test', '221JMT0105', UserRole.student, true),
    ('u-helene', 'Hélène Gharbi', 'helene.gharbi@campus.test', '221JMT0106', UserRole.student, true),
    ('u-rami', 'Rami Belhaj', 'rami.belhaj@campus.test', null, UserRole.student, false),
    ('u-selim', 'Selim Rekik', 'selim.rekik@campus.test', null, UserRole.alumni, true),
    ('u-nadia', 'Nadia Kooli', 'nadia.kooli@campus.test', null, UserRole.company, true),
    ('u-walid', 'Walid Sassi', 'walid.sassi@campus.test', null, UserRole.company, true),
  ];

  static const _notFound = ServerFailure('User not found.');
  static const _emailTaken = ServerFailure('An account with this email already exists.');
  static const _studentIdTaken = ServerFailure('This ENT ID is already in use.');

  /// No timer for a zero delay: widget tests can then call the repository
  /// outside of `pump` (a fake-async timer would never fire there).
  Future<void> _wait() => delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);

  String _sortKey(ManagedUser u) => foldAccents(u.displayName);

  bool _emailUsed(String email, {String? except}) =>
      _users.values.any((u) => u.email == email && u.id != except);

  bool _studentIdUsed(String studentId, {String? except}) =>
      _users.values.any((u) => u.studentId == studentId && u.id != except);

  void _record(String action, String summary, {String? targetId}) {
    final actor = _users[_currentUserId()];
    _audit.insert(
      0,
      AuditEntry(
        id: 'audit-${_audit.length + 1}',
        action: action,
        summary: summary,
        actorName: actor?.displayName,
        actorEmail: actor?.email,
        targetType: targetId == null ? null : 'user',
        targetId: targetId,
        ip: '127.0.0.1',
        userAgent: 'CampusPulse demo',
        createdAt: _now(),
      ),
    );
  }

  @override
  Future<Result<UserPage>> getUsers({
    String query = '',
    UserRole? role,
    int page = 1,
    int limit = 20,
  }) async {
    await _wait();
    final matches = _users.values
        .where((u) => role == null || u.role == role)
        .where((u) => matchesEveryWord(query, [u.displayName, u.email, u.studentId]))
        .toList()
      ..sort((a, b) {
        final byName = _sortKey(a).compareTo(_sortKey(b));
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
    final start = (page - 1) * limit;
    return Success(UserPage(
      items: matches.skip(start).take(limit).toList(),
      total: matches.length,
      page: page,
      limit: limit,
    ));
  }

  @override
  Future<Result<UserStats>> getStats() async {
    await _wait();
    return Success(UserStats(
      total: _users.length,
      byRole: {
        for (final role in UserRole.values)
          role: _users.values.where((u) => u.role == role).length,
      },
    ));
  }

  @override
  Future<Result<ManagedUser>> getUser(String id) async {
    await _wait();
    final user = _users[id];
    return user == null ? const Err(_notFound) : Success(user);
  }

  @override
  Future<Result<ManagedUser>> createUser(NewUser input) async {
    await _wait();
    final email = input.email.trim().toLowerCase();
    final studentId = input.studentId?.trim().toUpperCase() ?? '';
    if (_emailUsed(email)) return const Err(_emailTaken);
    if (studentId.isNotEmpty && _studentIdUsed(studentId)) return const Err(_studentIdTaken);
    final user = ManagedUser(
      id: 'u-new-${_nextId++}',
      email: email,
      displayName: input.displayName.trim(),
      role: input.role,
      studentId: studentId.isEmpty ? null : studentId,
      isEmailVerified: true,
      createdAt: _now(),
    );
    _users[user.id] = user;
    _record(
      'user.create',
      'Created the ${input.role.label.toLowerCase()} account $email',
      targetId: user.id,
    );
    return Success(user);
  }

  @override
  Future<Result<ManagedUser>> updateUser(String id, UserChanges c) async {
    await _wait();
    final before = _users[id];
    if (before == null) return const Err(_notFound);
    if (c.isEmpty) return const Err(ValidationFailure("There's nothing to save."));
    final own = id == _currentUserId();
    if (own && (c.role != null || c.password != null || c.isEmailVerified != null)) {
      return const Err(ValidationFailure(
        'On your own account, you can only change your name, email and ENT ID.',
      ));
    }
    final email = c.email?.trim().toLowerCase();
    if (email != null && _emailUsed(email, except: id)) return const Err(_emailTaken);
    final studentId = c.studentId?.trim().toUpperCase();
    if (studentId != null && studentId.isNotEmpty && _studentIdUsed(studentId, except: id)) {
      return const Err(_studentIdTaken);
    }

    final after = before.copyWith(
      displayName: c.displayName?.trim(),
      email: email,
      role: c.role,
      studentId: studentId == null ? null : () => studentId.isEmpty ? null : studentId,
      isEmailVerified: c.isEmailVerified,
    );
    _users[id] = after;
    final changed = [
      if (after.displayName != before.displayName) 'name',
      if (after.email != before.email) 'email',
      if (after.studentId != before.studentId) 'ENT ID',
      if (after.role != before.role) 'role',
      if (c.password != null) 'password',
      if (after.isEmailVerified != before.isEmailVerified) 'email verification',
    ];
    if (changed.isNotEmpty) {
      _record(
        'user.update',
        changed.length == 1 && after.role != before.role
            ? 'Changed the role of ${before.displayName} to ${after.role.label}'
            : 'Updated ${before.displayName} (${changed.join(', ')})',
        targetId: id,
      );
    }
    return Success(after);
  }

  @override
  Future<Result<void>> deleteUser(String id) async {
    await _wait();
    if (id == _currentUserId()) {
      return const Err(ValidationFailure("You can't delete your own account."));
    }
    final user = _users.remove(id);
    if (user == null) return const Err(_notFound);
    _record(
      'user.delete',
      'Deleted the account of ${user.displayName} (${user.email})',
      targetId: id,
    );
    return const Success(null);
  }

  /// The problems the server adds to the app's own checks: accounts that exist.
  List<ImportProblem> _serverProblems(List<ImportRow> rows) => [
        for (final r in rows) ...[
          if (_emailUsed(r.email))
            ImportProblem(
              row: r.row,
              field: 'email',
              code: 'EMAIL_TAKEN',
              message: 'Email: an account already uses it',
            ),
          if (r.studentId != null && _studentIdUsed(r.studentId!))
            ImportProblem(
              row: r.row,
              field: 'studentId',
              code: 'STUDENT_ID_TAKEN',
              message: 'ENT ID: an account already uses it',
            ),
        ],
      ];

  @override
  Future<Result<ImportCheck>> checkImport(List<ImportRow> rows) async {
    await _wait();
    if (rows.length > 1000) {
      return const Err(ValidationFailure('At most 1000 lines per check.'));
    }
    final problems = _serverProblems(rows);
    final bad = problems.map((p) => p.row).toSet();
    return Success(ImportCheck(valid: rows.where((r) => !bad.contains(r.row)).length, problems: problems));
  }

  @override
  Future<Result<ImportOutcome>> importUsers(List<ImportRow> rows) async {
    await _wait();
    if (rows.length > 50) {
      return const Err(ValidationFailure('At most 50 accounts per import.'));
    }
    final problems = _serverProblems(rows);
    if (problems.isNotEmpty) {
      return Success(ImportRefused('The file has errors, so nothing was imported.', problems));
    }
    final created = [
      for (final r in rows)
        ManagedUser(
          id: 'u-new-${_nextId++}',
          email: r.email,
          displayName: r.displayName,
          role: r.role ?? UserRole.student,
          studentId: r.studentId,
          createdAt: _now(),
        ),
    ];
    for (final u in created) {
      _users[u.id] = u;
    }
    _record(
      'user.import',
      created.length == 1 ? 'Imported 1 account' : 'Imported ${created.length} accounts',
    );
    return Success(ImportCreated(created));
  }

  @override
  Future<Result<ImportAssistStatus>> getImportAssistStatus() async {
    await _wait();
    return Success(ImportAssistStatus(
      available: assistAvailable,
      model: assistAvailable ? assistModel : null,
    ));
  }

  /// A fake AI: a deterministic guess from the lines, like the server's
  /// answer (title line, column of each field, meaning of each role value).
  @override
  Future<Result<ImportAssistAnswer>> assistImport(AssistRequest request) async {
    await _wait();
    if (!assistAvailable) {
      return const Err(ServerFailure('AI features are not available on this server.', 'AI_UNAVAILABLE'));
    }
    final failure = assistFailure;
    if (failure != null) return Err(failure);
    _record('user.import.assist', 'Asked the AI ($assistModel) how an import file is laid out');
    return Success(ImportAssistAnswer(mapping: guessImportLayout(request), model: assistModel));
  }

  @override
  Future<Result<AuditPage>> getAudit({String? action, int page = 1, int limit = 30}) async {
    await _wait();
    final matches = _audit.where((e) {
      if (action == null) return true;
      if (action.endsWith('*')) return e.action.startsWith(action.substring(0, action.length - 1));
      return e.action == action;
    }).toList();
    return Success(AuditPage(
      items: matches.skip((page - 1) * limit).take(limit).toList(),
      total: matches.length,
      page: page,
      limit: limit,
    ));
  }

  @override
  Future<Result<List<String>>> getAuditActions() async {
    await _wait();
    return Success(_audit.map((e) => e.action).toSet().toList()..sort());
  }
}

/// The mock AI's reading of [request]: the title line is the line above the
/// first email; a column of emails is the email, of `•••` the password, of
/// ENT IDs the ENT ID, of role words the role, of two words or more the full
/// name (family name first when its title says "Nom Prénom").
AssistMapping guessImportLayout(AssistRequest request) {
  final lines = request.lines;
  bool hasEmail(List<String> cells) => cells.any((c) => c.contains('@'));
  final firstEmail = lines.indexWhere(hasEmail);
  final headerRow = firstEmail > 0 ? firstEmail : 0;
  final data = lines.skip(headerRow).toList();
  final width = lines.fold(0, (w, cells) => w > cells.length ? w : cells.length);

  final columns = <AssistField, int>{};
  for (var column = 0; column < width; column++) {
    final cells = [
      for (final line in data)
        if (column < line.length && line[column].trim().isNotEmpty) line[column].trim(),
    ];
    if (cells.isEmpty) continue;
    final field = switch (cells) {
      _ when cells.every((c) => c.contains('@')) => AssistField.email,
      _ when cells.every((c) => c == maskedPassword) => AssistField.password,
      _ when cells.every((c) => _entId.hasMatch(c.toUpperCase())) => AssistField.studentId,
      _ when cells.where((c) => _guessRole(c) != null).length * 2 >= cells.length => AssistField.role,
      _ when cells.every((c) => c.split(RegExp(r'\s+')).length >= 2) => AssistField.fullName,
      _ => null,
    };
    if (field != null) columns.putIfAbsent(field, () => column);
  }

  final roleColumn = columns[AssistField.role];
  final title = headerRow > 0 && columns.containsKey(AssistField.fullName)
      ? foldAccents(lines[headerRow - 1][columns[AssistField.fullName]!]).replaceAll(RegExp('[^a-z]'), '')
      : '';
  final roleValues = roleColumn == null
      ? const <String>[]
      : {
          for (final line in data)
            if (roleColumn < line.length && line[roleColumn].trim().isNotEmpty) line[roleColumn].trim(),
        }.toList();
  return AssistMapping(
    headerRow: headerRow,
    columns: columns,
    nameOrder: title.startsWith('nomprenom') || title.startsWith('nometprenom')
        ? NameOrder.lastFirst
        : NameOrder.firstLast,
    roles: [for (final text in roleValues) (text: text, role: _guessRole(text))],
  );
}

final _entId = RegExp(r'^[0-9]{3}[A-Z]{3}[0-9]{4}$');

/// A role word, read loosely ("Enseignant(e) vacataire" is a teacher).
UserRole? _guessRole(String text) {
  final known = roleFromCell(text);
  if (known != null) return known;
  final key = foldAccents(text);
  if (key.contains('prof') || key.contains('enseign')) return UserRole.teacher;
  if (key.contains('etud') || key.contains('eleve') || key.contains('student')) return UserRole.student;
  if (key.contains('admin')) return UserRole.admin;
  if (key.contains('ancien') || key.contains('dipl') || key.contains('alumn')) return UserRole.alumni;
  if (key.contains('entreprise') || key.contains('recrut') || key.contains('company')) {
    return UserRole.company;
  }
  return null;
}
