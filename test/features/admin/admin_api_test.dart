import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/admin/data/models/admin_models.dart';
import 'package:campuspulse/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:campuspulse/features/admin/domain/entities/managed_user.dart';
import 'package:campuspulse/features/admin/domain/entities/user_import.dart';
import 'package:campuspulse/features/auth/data/models/auth_models.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/notifications/data/models/app_notification_model.dart';
import 'package:campuspulse/features/notifications/domain/entities/app_notification.dart';
import 'package:campuspulse/features/notifications/presentation/notification_routes.dart';
import 'package:campuspulse/core/router/route_names.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real responses of the backend (`backend/test/admin-*.test.ts`), saved by
/// running the API. If the API changes, regenerate them.
final Map<String, dynamic> _api = jsonDecode(
  File('test/features/admin/fixtures/admin_api.json').readAsStringSync(),
) as Map<String, dynamic>;

Map<String, dynamic> _json(String key) => _api[key] as Map<String, dynamic>;

/// Answers every request with [reply] and records what was sent.
class _FakeApi implements HttpClientAdapter {
  _FakeApi(this.reply);

  final (int, Object) Function(RequestOptions request) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(AdminRepositoryImpl, _FakeApi) _repo((int, Object) Function(RequestOptions) reply) {
  final api = _FakeApi(reply);
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))..httpClientAdapter = api;
  return (AdminRepositoryImpl(dio), api);
}

Failure _failureOf(Result<Object?> r) =>
    r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

void main() {
  group('contract', () {
    test('the session user carries its role', () {
      final user = UserModel.fromJson(_json('sessionUser')).toEntity();
      expect(user.role, UserRole.admin);
      expect(user.isAdmin, isTrue);
      expect(UserModel.fromJson({..._json('sessionUser'), 'role': 'dean'}).role, UserRole.student);
    });

    test('a page of users', () {
      final page = userPageFromJson(_json('usersPage'));

      expect(page.items.map((u) => u.role), [UserRole.teacher, UserRole.admin, UserRole.student]);
      expect(page.items.last.studentId, '221JMT0101');
      expect(page.items.first.studentId, isNull);
      expect(page.total, 4);
      expect(page.hasMore, isTrue);
    });

    test('stats, a user, the import answers and the audit log', () {
      expect(userStatsFromJson(_json('stats')).count(UserRole.alumni), 1);
      expect(managedUserFromJson(_json('managedUser')).createdAt.toUtc(),
          DateTime.utc(2026, 11, 9, 11, 36, 8, 796));

      final check = importCheckFromJson(_json('importDryRun'));
      expect(check.valid, 1);
      expect(check.problems.map((p) => p.code).toSet(), {
        'EMAIL_TAKEN', 'REQUIRED', 'INVALID_EMAIL', 'PASSWORD_TOO_SHORT', 'INVALID_ROLE',
        'DUPLICATE_STUDENT_ID',
      });

      final audit = auditPageFromJson(_json('auditPage'));
      expect(audit.items.map((e) => e.action), ['user.import', 'user.update', 'user.create']);
      expect(audit.items[1].summary, 'Changed the role of Sarra Mansouri to Teacher');
      expect(audit.items[1].actorName, 'Campus Admin');
      expect(audit.items.first.targetId, isNull);
      expect(audit.items.first.ip, '127.0.0.1');
    });

    test('account notifications open Profile and the new account', () {
      final update = AppNotificationModel.fromJson(_json('accountNotification')).toEntity();
      final signup = AppNotificationModel.fromJson(_json('signupNotification')).toEntity();

      expect(update.category, NotificationCategory.account);
      expect(notificationRoute(update.link!), RoutePaths.profile);
      expect(signup.link!.destination, NotificationDestination.adminUsers);
      expect(notificationRoute(signup.link!), RoutePaths.adminUser('6af1b02912b4298dadccaecc'));
    });
  });

  group('requests', () {
    test('getUsers sends the search, role and page', () async {
      final (repo, api) = _repo((_) => (200, _json('usersPage')));

      final page = (await repo.getUsers(query: ' sarra ', role: UserRole.student, page: 2)).unwrap();

      expect(api.requests.single.path, '/admin/users');
      expect(api.requests.single.queryParameters, {'q': 'sarra', 'role': 'student', 'page': 2, 'limit': 20});
      expect(page.items, hasLength(3));
    });

    test('createUser and updateUser send only what they should', () async {
      final (repo, api) = _repo((_) => (200, _json('managedUser')));

      await repo.createUser(const NewUser(
        displayName: ' Sarra ',
        email: 'Sarra@Campus.test',
        password: 'long-enough',
        studentId: '',
      ));
      await repo.updateUser('u1', const UserChanges(role: UserRole.teacher, studentId: ''));

      expect(api.requests[0].method, 'POST');
      expect(api.requests[0].data, {
        'displayName': 'Sarra',
        'email': 'sarra@campus.test',
        'password': 'long-enough',
        'role': 'student',
      });
      expect(api.requests[1].method, 'PATCH');
      expect(api.requests[1].path, '/admin/users/u1');
      expect(api.requests[1].data, {'studentId': null, 'role': 'teacher'});
    });

    test('UserChanges.between keeps only the differences', () {
      final before = managedUserFromJson(_json('managedUser'));
      final same = UserChanges.between(
        before,
        displayName: 'Sarra Mansouri ',
        email: 'SARRA.MANSOURI@campus.test',
        studentId: '221jmt0101',
        role: UserRole.student,
        password: '',
        isEmailVerified: true,
      );
      final changed = UserChanges.between(
        before,
        displayName: 'Sarra M.',
        email: 'sarra.mansouri@campus.test',
        studentId: '',
        role: UserRole.alumni,
        password: 'new-password',
        isEmailVerified: true,
      );

      expect(same.isEmpty, isTrue);
      expect(userChangesToJson(changed), {
        'displayName': 'Sarra M.',
        'studentId': null,
        'role': 'alumni',
        'password': 'new-password',
      });
    });

    test('the server message of a refusal is kept (403, 409)', () async {
      final (forbidden, _) = _repo((_) => (403, {'message': 'Only administrators can do this.'}));
      final (taken, _) = _repo((_) => (409, {'message': 'An account with this email already exists.'}));

      expect(_failureOf(await forbidden.getStats()).message, 'Only administrators can do this.');
      expect(
        _failureOf(await taken.createUser(
          const NewUser(displayName: 'X', email: 'x@campus.test', password: 'long-enough'),
        )).message,
        'An account with this email already exists.',
      );
    });

    group('import', () {
      const row = ImportRow(
        row: 2,
        displayName: 'Omar Ferchichi',
        email: 'omar.ferchichi@campus.test',
        password: 'long-enough',
        role: UserRole.student,
        studentId: '221JMT0102',
      );

      test('the check is a dry run', () async {
        final (repo, api) = _repo((_) => (200, _json('importDryRun')));

        final check = (await repo.checkImport([row])).unwrap();

        expect((api.requests.single.data as Map)['dryRun'], isTrue);
        expect((api.requests.single.data as Map)['users'], [
          {
            'row': 2,
            'displayName': 'Omar Ferchichi',
            'email': 'omar.ferchichi@campus.test',
            'password': 'long-enough',
            'role': 'student',
            'studentId': '221JMT0102',
          },
        ]);
        expect(check.problems, hasLength(6));
      });

      test('created accounts come back', () async {
        final (repo, _) = _repo((_) => (201, _json('importCreated')));
        final outcome = (await repo.importUsers([row])).unwrap();
        expect((outcome as ImportCreated).users.map((u) => u.displayName),
            ['Omar Ferchichi', 'Karim Trabelsi']);
      });

      test('a refused file is an answer with its problems, not an error', () async {
        final (repo, _) = _repo((_) => (422, _json('importInvalid')));

        final outcome = (await repo.importUsers([row])).unwrap();

        expect(outcome, isA<ImportRefused>());
        final refused = outcome as ImportRefused;
        expect(refused.message, 'The file has errors, so nothing was imported.');
        expect(refused.problems.first.code, 'EMAIL_TAKEN');
      });

      test('other 422s stay failures', () async {
        final (repo, _) = _repo((_) => (422, {'message': 'At most 50 accounts per import.'}));
        expect(_failureOf(await repo.importUsers([row])).message, 'At most 50 accounts per import.');
      });
    });

    test('getAudit sends the action filter; getAuditActions reads the list', () async {
      final (repo, api) = _repo(
        (r) => r.path.endsWith('/actions') ? (200, _api['auditActions']!) : (200, _json('auditPage')),
      );

      await repo.getAudit(action: 'user.*', page: 2);
      final actions = (await repo.getAuditActions()).unwrap();

      expect(api.requests.first.queryParameters, {'action': 'user.*', 'page': 2, 'limit': 30});
      expect(actions, ['user.create', 'user.import', 'user.update']);
    });
  });
}
