import 'dart:math';

import 'package:campuspulse/core/error/failures.dart';
import 'package:campuspulse/core/error/result.dart';
import 'package:campuspulse/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:campuspulse/features/admin/domain/import_assist.dart';
import 'package:campuspulse/features/admin/domain/user_import_parser.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// A file that doesn't follow the template: a note on line 1, French titles
/// on line 2, one full-name column, loose roles, passwords.
const _file = 'Liste promo 2026;;;;\n'
    'Nom et prénom;Adresse;Profil;MDP;Matricule\n'
    'BEN ALI Ines;ines.benali@campus.test;Étudiant(e);Secret-123;221JMT0201\n'
    'Karim Trabelsi;karim.trabelsi@campus.test;Enseignant vacataire;Password1;\n'
    '\n'
    'EL AMRI Sarra;sarra.elamri@campus.test;Étudiant(e);Kp7m-x2Qa-77;221JMT0202\n';

void main() {
  group('maskEmails', () {
    test('keeps the first letter and the domain', () {
      expect(maskEmails('ines.benali@esprit.tn'), 'i…@esprit.tn');
      expect(maskEmails('Ines <ines@campus.test>, k@x.tn'), 'Ines <i…@campus.test>, k…@x.tn');
      expect(maskEmails('no email here'), 'no email here');
    });
  });

  group('assistRequest', () {
    test('masks emails, and passwords by position under their title', () {
      final request = assistRequest(readImportTable(_file));

      expect(request.lines, [
        ['Liste promo 2026', '', '', '', ''],
        ['Nom et prénom', 'Adresse', 'Profil', 'MDP', 'Matricule'],
        ['BEN ALI Ines', 'i…@campus.test', 'Étudiant(e)', maskedPassword, '221JMT0201'],
        // "Password1" looks like a title, but it is a cell of the MDP column.
        ['Karim Trabelsi', 'k…@campus.test', 'Enseignant vacataire', maskedPassword, ''],
        // The blank line is not sent.
        ['EL AMRI Sarra', 's…@campus.test', 'Étudiant(e)', maskedPassword, '221JMT0202'],
      ]);
    });

    test('sends the distinct values of short columns, never emails or passwords', () {
      final request = assistRequest(readImportTable(_file));

      expect(request.values.map((v) => v.column), [0, 2, 4]);
      expect(request.values.map((v) => v.values), [
        ['Liste promo 2026', 'Nom et prénom', 'BEN ALI Ines', 'Karim Trabelsi', 'EL AMRI Sarra'],
        ['Profil', 'Étudiant(e)', 'Enseignant vacataire'],
        ['Matricule', '221JMT0201', '221JMT0202'],
      ]);
    });

    test('at most 12 lines of 15 cells of 80 characters; long columns are not listed', () {
      final table = [
        for (var i = 1; i <= 30; i++)
          (line: i, cells: [for (var j = 0; j < 20; j++) j == 0 ? 'Name $i' : 'x' * 100]),
      ];
      final request = assistRequest(table);

      expect(request.lines, hasLength(assistLines));
      expect(request.lines.first, hasLength(15));
      expect(request.lines.first[1], hasLength(80));
      // 30 names: more than 30 / 3 distinct values.
      expect(request.values.map((v) => v.column), isNot(contains(0)));
    });
  });

  group('splitFullName', () {
    test('the words in capitals are the family name, wherever they are', () {
      expect(splitFullName('BEN ALI Ines', NameOrder.lastFirst), (lastName: 'BEN ALI', firstName: 'Ines'));
      expect(splitFullName('Ines BEN ALI', NameOrder.lastFirst), (lastName: 'BEN ALI', firstName: 'Ines'));
      expect(
        splitFullName("Mohamed Amine N'DIAYE", NameOrder.lastFirst),
        (lastName: "N'DIAYE", firstName: 'Mohamed Amine'),
      );
      expect(splitFullName('ÉLODIE Hélène', NameOrder.firstLast), (lastName: 'ÉLODIE', firstName: 'Hélène'));
    });

    test('otherwise the first or last word, with its particles', () {
      expect(splitFullName('Ben Ali Ines', NameOrder.lastFirst), (lastName: 'Ben Ali', firstName: 'Ines'));
      expect(splitFullName('Ines Ben Ali', NameOrder.firstLast), (lastName: 'Ben Ali', firstName: 'Ines'));
      expect(splitFullName('El Amri Sarra', NameOrder.lastFirst), (lastName: 'El Amri', firstName: 'Sarra'));
      expect(
        splitFullName('Jean de la Fontaine', NameOrder.firstLast),
        (lastName: 'de la Fontaine', firstName: 'Jean'),
      );
      expect(splitFullName('Trabelsi Karim', NameOrder.lastFirst), (lastName: 'Trabelsi', firstName: 'Karim'));
      expect(splitFullName('Karim Trabelsi', NameOrder.firstLast), (lastName: 'Trabelsi', firstName: 'Karim'));
    });

    test('one word is a family name; all capitals follow the order', () {
      expect(splitFullName(' Ines ', NameOrder.lastFirst), (lastName: 'Ines', firstName: ''));
      expect(splitFullName('', NameOrder.firstLast), (lastName: '', firstName: ''));
      expect(splitFullName('BEN ALI INES', NameOrder.lastFirst), (lastName: 'BEN ALI', firstName: 'INES'));
    });
  });

  group('applyAssist', () {
    const mapping = AssistMapping(
      headerRow: 2,
      columns: {
        AssistField.fullName: 0,
        AssistField.email: 1,
        AssistField.role: 2,
        AssistField.password: 3,
        AssistField.studentId: 4,
      },
      nameOrder: NameOrder.firstLast,
      roles: [
        (text: 'Étudiant(e)', role: UserRole.student),
        (text: 'Enseignant vacataire', role: UserRole.teacher),
      ],
    );

    test('rewrites the file as the template, keeping the line numbers', () {
      final table = applyAssist(readImportTable(_file), mapping);

      // The note above the titles is dropped.
      expect(table.map((l) => l.line), [2, 3, 4, 6]);
      expect(table.map((l) => l.cells), [
        assistTitles,
        ['Ines', 'BEN ALI', 'ines.benali@campus.test', '221JMT0201', 'student', 'Secret-123'],
        ['Karim', 'Trabelsi', 'karim.trabelsi@campus.test', '', 'teacher', 'Password1'],
        ['Sarra', 'EL AMRI', 'sarra.elamri@campus.test', '221JMT0202', 'student', 'Kp7m-x2Qa-77'],
      ]);
    });

    test('the parser then reads every line, with the lines of the file', () {
      // "Adresse" isn't a known title.
      expect(parseUserImport(_file).missingColumns, ['Email']);

      final parsed = parseImportTable(applyAssist(readImportTable(_file), mapping), random: Random(1));

      expect(parsed.isUsable, isTrue);
      expect(parsed.problems, isEmpty);
      expect(
        parsed.rows.map((r) => (r.row, r.displayName, r.role, r.studentId, r.password)),
        [
          (3, 'Ines BEN ALI', UserRole.student, '221JMT0201', 'Secret-123'),
          (4, 'Karim Trabelsi', UserRole.teacher, null, 'Password1'),
          (6, 'Sarra EL AMRI', UserRole.student, '221JMT0202', 'Kp7m-x2Qa-77'),
        ],
      );
    });

    test('without a title line, the titles are added on top as line 0', () {
      const noTitles = 'Ines Ben Ali,ines@campus.test,prof\nSarra Kefi,sarra@campus.test,boss\n';
      const mapping = AssistMapping(
        headerRow: 0,
        columns: {AssistField.fullName: 0, AssistField.email: 1, AssistField.role: 2},
        nameOrder: NameOrder.firstLast,
        roles: [(text: 'prof', role: UserRole.teacher), (text: 'boss', role: null)],
      );

      final table = applyAssist(readImportTable(noTitles), mapping);
      final parsed = parseImportTable(table, random: Random(1));

      expect(table.first.line, 0);
      expect(table.first.cells, assistTitles);
      expect(parsed.rows.map((r) => (r.row, r.displayName, r.role)), [
        (1, 'Ines Ben Ali', UserRole.teacher),
        (2, 'Sarra Kefi', null),
      ]);
      // A value the AI couldn't read stays as written: the line has to be fixed.
      expect(parsed.problems.single.code, 'INVALID_ROLE');
      expect(parsed.problems.single.row, 2);
    });

    test('separate name columns are kept as they are', () {
      const csv = 'Famille;Prénom usuel;Mail\nBen Ali;Ines;ines@campus.test\n';
      const mapping = AssistMapping(
        headerRow: 1,
        columns: {AssistField.lastName: 0, AssistField.firstName: 1, AssistField.email: 2},
      );

      final parsed = parseImportTable(applyAssist(readImportTable(csv), mapping));

      expect(parsed.rows.single.displayName, 'Ines Ben Ali');
      expect(parsed.rows.single.row, 2);
    });
  });

  test('columnLetter names columns like a spreadsheet', () {
    expect([0, 1, 25, 26, 27, 51, 52, 701, 702].map(columnLetter),
        ['A', 'B', 'Z', 'AA', 'AB', 'AZ', 'BA', 'ZZ', 'AAA']);
  });

  group('MockAdminRepository', () {
    MockAdminRepository repo({bool available = true}) => MockAdminRepository(
          delay: Duration.zero,
          now: () => DateTime(2026, 11, 13, 10),
          assistAvailable: available,
        );

    test('the fake AI reads the layout of the file, and it is audited', () async {
      final mock = repo();
      expect((await mock.getImportAssistStatus()).unwrap().available, isTrue);

      final answer = (await mock.assistImport(assistRequest(readImportTable(_file)))).unwrap();

      expect(answer.model, MockAdminRepository.assistModel);
      expect(answer.mapping.headerRow, 2);
      expect(answer.mapping.columns, {
        AssistField.fullName: 0,
        AssistField.email: 1,
        AssistField.role: 2,
        AssistField.password: 3,
        AssistField.studentId: 4,
      });
      // "Nom et prénom": the family name comes first.
      expect(answer.mapping.nameOrder, NameOrder.lastFirst);
      expect(answer.mapping.roles, [
        (text: 'Étudiant(e)', role: UserRole.student),
        (text: 'Enseignant vacataire', role: UserRole.teacher),
      ]);
      final audit = (await mock.getAudit()).unwrap().items;
      expect(audit.single.action, 'user.import.assist');
    });

    test('not available, or failing like the server', () async {
      final off = repo(available: false);
      expect((await off.getImportAssistStatus()).unwrap().available, isFalse);
      final refused = await off.assistImport(const AssistRequest(lines: [['a']], values: []));
      expect(refused.when(success: (_) => null, failure: (f) => f.code), 'AI_UNAVAILABLE');

      final busy = repo()
        ..assistFailure = const TooManyRequestsFailure(
          'The AI service is busy. Try again in a few minutes.',
          'AI_BUSY',
        );
      final result = await busy.assistImport(const AssistRequest(lines: [['a']], values: []));
      expect(result, isA<Err<Object?>>());
      expect(
        result.when(success: (_) => null, failure: (f) => f.message),
        'The AI service is busy. Try again in a few minutes.',
      );
      expect((await busy.getAudit()).unwrap().items, isEmpty);
    });
  });
}
