import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:campuspulse/features/admin/domain/entities/managed_user.dart';
import 'package:campuspulse/features/admin/domain/entities/user_import.dart';
import 'package:campuspulse/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// The mock follows the API's rules, so the screens behave the same offline.
void main() {
  late MockAdminRepository repo;
  const me = MockAuthRemoteDataSource.adminId;

  setUp(() {
    repo = MockAdminRepository(delay: Duration.zero, now: () => DateTime(2026, 11, 9, 10));
  });

  Failure failureOf(Result<Object?> r) =>
      r.when(success: (_) => fail('expected a failure'), failure: (f) => f);

  group('listing', () {
    test('sorts by name, ignoring accents, and pages', () async {
      final first = (await repo.getUsers(limit: 5)).unwrap();
      final second = (await repo.getUsers(page: 3, limit: 5)).unwrap();

      expect(first.total, 12);
      expect(first.items.map((u) => u.displayName).take(3), ['Amira Ben Salah', 'Campus Admin', 'Dony Mansour']);
      expect(first.hasMore, isTrue);
      expect(second.items, hasLength(2));
      expect(second.hasMore, isFalse);
    });

    test('every word of the search must match, without accents', () async {
      final helene = (await repo.getUsers(query: 'helene GHARBI')).unwrap();
      final byId = (await repo.getUsers(query: '221jmt0104')).unwrap();
      final none = (await repo.getUsers(query: 'helene trabelsi')).unwrap();

      expect(helene.items.single.displayName, 'Hélène Gharbi');
      expect(byId.items.single.displayName, 'Inès Zouari');
      expect(none.total, 0);
    });

    test('filters by role, and counts every role', () async {
      final teachers = (await repo.getUsers(role: UserRole.teacher)).unwrap();
      final stats = (await repo.getStats()).unwrap();

      expect(teachers.items.map((u) => u.displayName), ['Amira Ben Salah', 'Karim Trabelsi']);
      expect(stats.total, 12);
      expect(stats.count(UserRole.student), 8);
      expect(stats.count(UserRole.teacher), 2);
      expect(stats.count(UserRole.admin), 1);
      expect(stats.count(UserRole.alumni), 1);
    });
  });

  group('creating', () {
    test('creates a verified account and records it', () async {
      final user = (await repo.createUser(const NewUser(
        displayName: ' Lina Bouazizi ',
        email: 'Lina.Bouazizi@Campus.test',
        password: 'long-enough',
        role: UserRole.teacher,
        studentId: '231jmt0001',
      )))
          .unwrap();

      expect(user.displayName, 'Lina Bouazizi');
      expect(user.email, 'lina.bouazizi@campus.test');
      expect(user.studentId, '231JMT0001');
      expect(user.isEmailVerified, isTrue);
      final audit = (await repo.getAudit()).unwrap();
      expect(audit.items.single.summary, 'Created the teacher account lina.bouazizi@campus.test');
      expect(audit.items.single.actorName, 'Campus Admin');
    });

    test('refuses an email or ENT ID already in use', () async {
      final email = await repo.createUser(
        const NewUser(displayName: 'X', email: 'sarra.mansouri@campus.test', password: 'long-enough'),
      );
      final studentId = await repo.createUser(const NewUser(
        displayName: 'X',
        email: 'x@campus.test',
        password: 'long-enough',
        studentId: '221JMT0101',
      ));

      expect(failureOf(email).message, 'An account with this email already exists.');
      expect(failureOf(studentId).message, 'This ENT ID is already in use.');
    });
  });

  group('editing', () {
    test('changes the role and records it', () async {
      final user = (await repo.updateUser('u-sarra', const UserChanges(role: UserRole.teacher))).unwrap();

      expect(user.role, UserRole.teacher);
      expect(
        (await repo.getAudit(action: 'user.*')).unwrap().items.single.summary,
        'Changed the role of Sarra Mansouri to Teacher',
      );
    });

    test('an empty ENT ID removes it', () async {
      final user = (await repo.updateUser('u-sarra', const UserChanges(studentId: ''))).unwrap();
      expect(user.studentId, isNull);
    });

    test('on your own account, only the name, email and ENT ID can change', () async {
      final renamed = await repo.updateUser(me, const UserChanges(displayName: 'Head Admin'));
      final demoted = await repo.updateUser(me, const UserChanges(role: UserRole.student));
      final password = await repo.updateUser(me, const UserChanges(password: 'long-enough'));

      expect(renamed.unwrap().displayName, 'Head Admin');
      expect(
        failureOf(demoted).message,
        'On your own account, you can only change your name, email and ENT ID.',
      );
      expect(failureOf(password), isA<ValidationFailure>());
    });

    test('refuses nothing to save, unknown accounts and a taken email', () async {
      expect(failureOf(await repo.updateUser('u-sarra', const UserChanges())).message,
          "There's nothing to save.");
      expect(failureOf(await repo.updateUser('nope', const UserChanges(displayName: 'X'))).message,
          'User not found.');
      expect(
        failureOf(await repo.updateUser(
          'u-sarra',
          const UserChanges(email: 'omar.ferchichi@campus.test'),
        )).message,
        'An account with this email already exists.',
      );
    });
  });

  group('deleting', () {
    test('deletes another account', () async {
      (await repo.deleteUser('u-selim')).unwrap();

      expect(failureOf(await repo.getUser('u-selim')).message, 'User not found.');
      expect(
        (await repo.getAudit(action: 'user.delete')).unwrap().items.single.summary,
        'Deleted the account of Selim Rekik (selim.rekik@campus.test)',
      );
    });

    test("refuses the admin's own account", () async {
      expect(failureOf(await repo.deleteUser(me)).message, "You can't delete your own account.");
    });
  });

  group('importing', () {
    const fresh = ImportRow(
      row: 2,
      displayName: 'Lina Bouazizi',
      email: 'lina@campus.test',
      password: 'long-enough',
      role: UserRole.student,
    );
    const taken = ImportRow(
      row: 3,
      displayName: 'Sarra again',
      email: 'sarra.mansouri@campus.test',
      password: 'long-enough',
      role: UserRole.student,
      studentId: '221JMT0101',
    );

    test('the check reports accounts that already exist', () async {
      final check = (await repo.checkImport([fresh, taken])).unwrap();

      expect(check.valid, 1);
      expect(check.problems.map((p) => (p.row, p.code)), [(3, 'EMAIL_TAKEN'), (3, 'STUDENT_ID_TAKEN')]);
    });

    test('is all or nothing', () async {
      final refused = (await repo.importUsers([fresh, taken])).unwrap();
      expect(refused, isA<ImportRefused>());
      expect((await repo.getStats()).unwrap().total, 12);

      final created = (await repo.importUsers([fresh])).unwrap();
      expect((created as ImportCreated).users.single.email, 'lina@campus.test');
      expect((await repo.getStats()).unwrap().total, 13);
      expect((await repo.getAuditActions()).unwrap(), ['user.import']);
    });

    test('refuses more than 50 accounts at once', () async {
      final rows = [
        for (var i = 0; i < 51; i++)
          ImportRow(row: i + 2, displayName: 'U$i', email: 'u$i@campus.test', password: 'long-enough'),
      ];
      expect(failureOf(await repo.importUsers(rows)).message, 'At most 50 accounts per import.');
    });
  });
}
