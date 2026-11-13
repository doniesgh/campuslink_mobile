import 'package:campuspulse/core/router/route_names.dart';
import 'package:campuspulse/core/theme/app_colors.dart';
import 'package:campuspulse/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:campuspulse/features/admin/domain/entities/managed_user.dart';
import 'package:campuspulse/features/admin/domain/entities/user_import.dart';
import 'package:campuspulse/features/admin/presentation/pages/admin_users_page.dart';
import 'package:campuspulse/features/admin/presentation/pages/audit_log_page.dart';
import 'package:campuspulse/features/admin/presentation/pages/import_users_page.dart';
import 'package:campuspulse/features/admin/presentation/pages/user_form_page.dart';
import 'package:campuspulse/features/admin/presentation/providers/admin_providers.dart';
import 'package:campuspulse/features/admin/presentation/providers/import_file_picker.dart';
import 'package:campuspulse/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:campuspulse/features/auth/presentation/providers/auth_controller.dart';
import 'package:campuspulse/shared/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _AdminAuth extends AuthController {
  @override
  Future<User?> build() async => const User(
        id: MockAuthRemoteDataSource.adminId,
        email: 'admin@campus.test',
        displayName: 'Campus Admin',
        isEmailVerified: true,
        role: UserRole.admin,
      );
}

/// The admin screens with the app's nesting (Profile › admin/...), on the
/// mock repository (14 demo accounts), at [width] dp with [textScale] text.
Future<MockAdminRepository> _pump(
  WidgetTester tester,
  String location, {
  MockAdminRepository? repo,
  Future<PickedTextFile?> Function()? picker,
  Brightness brightness = Brightness.light,
  double width = 360,
  double textScale = 1.3,
}) async {
  tester.view.physicalSize = Size(width, 800) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final repository = repo ?? MockAdminRepository(delay: Duration.zero, now: () => DateTime(2026, 11, 9, 10));
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: RoutePaths.profile,
        builder: (_, __) => const Scaffold(body: Center(child: Text('Profile screen'))),
        routes: [
          GoRoute(
            path: 'admin/users',
            builder: (_, __) => const AdminUsersPage(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const UserFormPage()),
              GoRoute(
                path: ':userId',
                builder: (_, state) => UserFormPage(userId: state.pathParameters['userId']),
              ),
            ],
          ),
          GoRoute(path: 'admin/import', builder: (_, __) => const ImportUsersPage()),
          GoRoute(path: 'admin/audit', builder: (_, __) => const AuditLogPage()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_AdminAuth.new),
        adminRepositoryProvider.overrideWithValue(repository),
        if (picker != null) importFilePickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp.router(
        // Plain theme: the app theme pulls Google Fonts from the network.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness),
        ),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Finder _field(String label) => find.descendant(
      of: find.widgetWithText(AppTextField, label),
      matching: find.byType(TextFormField),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Records what the app puts in the clipboard.
List<String> _captureClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copied;
}

void main() {
  group('Users', () {
    for (final brightness in Brightness.values) {
      testWidgets('lists the accounts with their role at 360 dp ($brightness)', (tester) async {
        await _pump(tester, RoutePaths.adminUsers, brightness: brightness);

        expect(find.text('14 accounts'), findsOneWidget);
        expect(find.text('Campus Admin (you)'), findsOneWidget);
        expect(find.text('Amira Ben Salah'), findsOneWidget);
        expect(find.text('Email not verified'), findsNothing, reason: 'Rami is further down');
        expect(find.text('Add user'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('filters by role with the chips', (tester) async {
      await _pump(tester, RoutePaths.adminUsers);

      await _tap(tester, find.text('Teachers'));

      expect(find.text('2 results'), findsOneWidget);
      expect(find.text('Amira Ben Salah'), findsOneWidget);
      expect(find.text('Karim Trabelsi'), findsOneWidget);
      expect(find.text('Campus Admin (you)'), findsNothing);
    });

    testWidgets('searches once typing stops, ignoring accents', (tester) async {
      await _pump(tester, RoutePaths.adminUsers);

      await tester.enterText(find.byType(TextField).first, 'helene');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('14 accounts'), findsOneWidget, reason: 'not yet');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('1 result'), findsOneWidget);
      expect(find.text('Hélène Gharbi'), findsOneWidget);
    });

    testWidgets('loads the next page at the end of the list', (tester) async {
      final repo = MockAdminRepository(delay: Duration.zero);
      await repo.importUsers([
        for (var i = 0; i < 25; i++)
          ImportRow(
            row: i + 2,
            displayName: 'Zz Student ${i.toString().padLeft(2, '0')}',
            email: 'zz$i@campus.test',
            password: 'long-enough',
          ),
      ]);
      await _pump(tester, RoutePaths.adminUsers, repo: repo, textScale: 1);

      expect(find.text('39 accounts'), findsOneWidget);
      // The last Scrollable is the list (the search field and the chips have one too).
      await tester.scrollUntilVisible(
        find.text('Zz Student 24'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Zz Student 24'), findsOneWidget);
    });

    testWidgets('opens an account to edit it', (tester) async {
      await _pump(tester, RoutePaths.adminUsers);
      await _tap(tester, find.text('Amira Ben Salah'));
      expect(find.text('Edit Amira Ben Salah'), findsOneWidget);
    });
  });

  group('Add user', () {
    for (final brightness in Brightness.values) {
      testWidgets('renders at 360 dp ($brightness)', (tester) async {
        await _pump(tester, RoutePaths.newUser, brightness: brightness);
        expect(find.text('Add user'), findsOneWidget);
        expect(find.text('Generate'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('checks the fields, creates the account and shows its sign-in details',
        (tester) async {
      final repo = await _pump(tester, RoutePaths.adminUsers);
      await _tap(tester, find.text('Add user'));

      await _tap(tester, find.text('Create'));
      expect(find.text('Enter the name'), findsOneWidget);
      expect(find.text('Enter the email'), findsOneWidget);
      expect(find.text('Choose a password'), findsOneWidget);

      await tester.enterText(_field('Name'), 'Lina Bouazizi');
      await tester.enterText(_field('Email'), 'lina.bouazizi@campus.test');
      await tester.enterText(_field('Password'), 'Welcome-2026');
      await _tap(tester, find.text('Teacher'));
      await _tap(tester, find.text('Create'));

      expect(find.text('Account created'), findsOneWidget);
      expect(find.textContaining('Password: Welcome-2026'), findsOneWidget);
      await _tap(tester, find.text('Done'));

      expect(find.text('Lina Bouazizi has been added.'), findsOneWidget);
      expect(find.text('15 accounts'), findsOneWidget);
      final created = (await repo.getUsers(query: 'lina')).unwrap().items.single;
      expect(created.role, UserRole.teacher);
    });

    testWidgets('creates a company account: the fifth role takes a whole row', (tester) async {
      final repo = await _pump(tester, RoutePaths.newUser);
      Size card(String role) =>
          tester.getSize(find.ancestor(of: find.text(role), matching: find.byType(InkWell)).first);

      await tester.ensureVisible(find.text('Recruiter / partner company'));
      await tester.pumpAndSettle();
      expect(card('Company').width, greaterThan(card('Student').width * 1.8));
      expect(card('Teacher').width, card('Student').width);
      expect(tester.takeException(), isNull);

      await tester.enterText(_field('Name'), 'Nadia Kooli');
      await tester.enterText(_field('Email'), 'nadia.k@medinasoft.test');
      await tester.enterText(_field('Password'), 'Welcome-2026');
      await _tap(tester, find.text('Company'));
      await _tap(tester, find.text('Create'));

      expect(find.text('Account created'), findsOneWidget);
      final created = (await repo.getUsers(query: 'medinasoft')).unwrap().items.single;
      expect(created.role, UserRole.company);
    });

    testWidgets('shows the server refusal', (tester) async {
      await _pump(tester, RoutePaths.newUser);
      await tester.enterText(_field('Name'), 'Sarra Again');
      await tester.enterText(_field('Email'), 'sarra.mansouri@campus.test');
      await tester.enterText(_field('Password'), 'Welcome-2026');
      await _tap(tester, find.text('Create'));

      expect(find.text('An account with this email already exists.'), findsOneWidget);
      expect(find.text('Account created'), findsNothing);
    });
  });

  group('Edit user', () {
    for (final brightness in Brightness.values) {
      testWidgets('renders another account at 360 dp ($brightness)', (tester) async {
        await _pump(tester, RoutePaths.adminUser('u-rami'), brightness: brightness);
        expect(find.text('Edit Rami Belhaj'), findsOneWidget);
        expect(find.text('Email verified'), findsOneWidget);
        await tester.ensureVisible(find.text('Delete this account'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('changes the role', (tester) async {
      // Opened directly: go_router puts the Users list below it.
      final repo = await _pump(tester, RoutePaths.adminUser('u-ines'));

      await _tap(tester, find.text('Alumni'));
      await _tap(tester, find.text('Save'));

      expect(find.text('Inès Zouari has been updated.'), findsOneWidget);
      expect((await repo.getUser('u-ines')).unwrap().role, UserRole.alumni);
    });

    testWidgets('a new password is shown once in the sign-in details', (tester) async {
      await _pump(tester, RoutePaths.adminUser('u-omar'));
      await tester.enterText(_field('New password (optional)'), 'Fresh-pass-1');
      await _tap(tester, find.text('Save'));

      expect(find.text('New password'), findsOneWidget);
      expect(find.textContaining('Password: Fresh-pass-1'), findsOneWidget);
    });

    testWidgets('nothing changed: nothing is sent', (tester) async {
      await _pump(tester, RoutePaths.adminUser('u-omar'));
      await _tap(tester, find.text('Save'));
      expect(find.text("There's nothing to save."), findsOneWidget);
    });

    testWidgets('on your own account, the role, password and delete are hidden', (tester) async {
      await _pump(tester, RoutePaths.adminUser(MockAuthRemoteDataSource.adminId));

      expect(find.text('This is your account'), findsOneWidget);
      expect(find.text('Role'), findsNothing);
      expect(find.text('New password (optional)'), findsNothing);
      expect(find.text('Delete this account'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deletes an account after confirmation', (tester) async {
      final repo = await _pump(tester, RoutePaths.adminUser('u-amira'));

      await _tap(tester, find.text('Delete this account'));
      expect(find.text('Delete Amira Ben Salah?'), findsOneWidget);
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));

      expect(find.text('Amira Ben Salah has been deleted.'), findsOneWidget);
      expect(find.text('13 accounts'), findsOneWidget);
      expect((await repo.getStats()).unwrap().total, 13);
    });

    testWidgets('an unknown account shows the error', (tester) async {
      await _pump(tester, RoutePaths.adminUser('gone'));
      expect(find.text('User not found.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('Import', () {
    const csv = 'Nom;Prénom;Courriel;Rôle\n'
        'Bouazizi;Lina;lina.bouazizi@campus.test;Étudiante\n'
        'Mansouri;Sarra;sarra.mansouri@campus.test;\n'
        'Sans;Courriel;;prof\n';

    for (final brightness in Brightness.values) {
      testWidgets('renders the first step at 360 dp ($brightness)', (tester) async {
        await _pump(tester, RoutePaths.importUsers, brightness: brightness);
        expect(find.text('Import accounts'), findsOneWidget);
        expect(find.text('Choose a CSV file'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('checks pasted cells, leaves out the bad lines and imports the rest',
        (tester) async {
      final copied = _captureClipboard(tester);
      final repo = await _pump(tester, RoutePaths.importUsers);

      await tester.enterText(find.byType(TextField), csv);
      await _tap(tester, find.text('Read the rows'));

      expect(find.text('Check the lines'), findsOneWidget);
      expect(find.text('3 lines'), findsOneWidget);
      expect(find.text('1 ready'), findsOneWidget);
      expect(find.text('2 to fix'), findsOneWidget);
      expect(find.text('Checked with the server.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Email: missing'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Email: an account already uses it'), findsOneWidget);
      expect(find.text('Email: missing'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final import = find.widgetWithText(FilledButton, 'Import');
      expect(tester.widget<FilledButton>(import).onPressed, isNull);
      await _tap(tester, find.textContaining('Import the 1 correct accounts'));
      await _tap(tester, import);

      expect(find.text('Import finished'), findsOneWidget);
      expect(find.text('1 account created.'), findsOneWidget);
      expect((await repo.getUsers(query: 'lina')).unwrap().total, 1);

      await _tap(tester, find.text('Copy the sign-in details'));
      expect(copied.single, startsWith('Name\tEmail\tENT ID\tRole\tPassword\nLina Bouazizi\t'));
      await _tap(tester, find.text('Done'));
      expect(find.text('Profile screen'), findsOneWidget);
    });

    testWidgets('warns before leaving with generated passwords not copied', (tester) async {
      await _pump(tester, RoutePaths.importUsers);
      await tester.enterText(find.byType(TextField), 'Name,Email\nLina Bouazizi,lina@campus.test\n');
      await _tap(tester, find.text('Read the rows'));
      await _tap(tester, find.widgetWithText(FilledButton, 'Import'));

      await _tap(tester, find.text('Done'));
      expect(find.text('Leave without the passwords?'), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect(find.text('Import finished'), findsOneWidget);

      await _tap(tester, find.text('Done'));
      await _tap(tester, find.text('Leave anyway'));
      expect(find.text('Profile screen'), findsOneWidget);
    });

    testWidgets('reads a chosen file', (tester) async {
      await _pump(
        tester,
        RoutePaths.importUsers,
        picker: () async => (name: 'promo-2026.csv', text: csv),
      );
      await _tap(tester, find.text('Choose a CSV file'));

      expect(find.text('promo-2026.csv'), findsOneWidget);
      expect(find.text('3 lines'), findsOneWidget);
    });

    testWidgets('explains why a file is refused', (tester) async {
      await _pump(
        tester,
        RoutePaths.importUsers,
        picker: () async => throw const ImportFileException('This file is too big (at most 5 MB).'),
      );
      await _tap(tester, find.text('Choose a CSV file'));
      expect(find.text('This file is too big (at most 5 MB).'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Name,Phone\nLina,123\n');
      await _tap(tester, find.text('Read the rows'));
      expect(
        find.text('Columns not found: Email. Put the column titles on the first line.'),
        findsOneWidget,
      );
    });
  });

  group('Audit log', () {
    for (final brightness in Brightness.values) {
      testWidgets('lists the changes, newest first, and filters them ($brightness)',
          (tester) async {
        final repo = MockAdminRepository(delay: Duration.zero, now: () => DateTime(2026, 11, 9, 10));
        await repo.deleteUser('u-selim');
        await repo.updateUser('u-sarra', const UserChanges(role: UserRole.teacher));
        await _pump(tester, RoutePaths.auditLog, repo: repo, brightness: brightness);

        expect(find.text('Changed the role of Sarra Mansouri to Teacher'), findsOneWidget);
        expect(find.text('Deleted the account of Selim Rekik (selim.rekik@campus.test)'), findsOneWidget);
        expect(find.textContaining('By Campus Admin'), findsNWidgets(2));
        expect(tester.takeException(), isNull);

        await _tap(tester, find.text('Deleted'));
        expect(find.text('Changed the role of Sarra Mansouri to Teacher'), findsNothing);
        expect(find.text('Deleted the account of Selim Rekik (selim.rekik@campus.test)'), findsOneWidget);
      });
    }

    test('names every action the API records', () {
      expect(auditActionLabel('user.import.assist'), 'Import assist');
      expect(auditActionLabel('auth.password_reset'), 'Password reset');
      expect(auditActionLabel('auth.password_change'), 'Password changed');
      expect(auditActionLabel('something.new'), 'something.new');
      expect(auditActionIcon('auth.password_reset'), Icons.lock_reset_outlined);
    });

    testWidgets('is empty before any change', (tester) async {
      await _pump(tester, RoutePaths.auditLog);
      expect(find.text('Nothing recorded yet.'), findsOneWidget);
    });
  });
}
