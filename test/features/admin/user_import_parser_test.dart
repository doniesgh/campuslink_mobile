import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:campuspulse/features/admin/domain/entities/user_import.dart';
import 'package:campuspulse/features/admin/domain/user_import_parser.dart';
import 'package:campuspulse/features/admin/presentation/providers/import_file_picker.dart';
import 'package:campuspulse/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

ParsedImport _parse(String text) => parseUserImport(text, random: Random(1));

List<String> _codes(ParsedImport p, int row) =>
    [for (final problem in p.problems) if (problem.row == row) problem.code];

void main() {
  group('reading the file', () {
    test('reads a comma-separated file with the template titles', () {
      final p = _parse(
        'Name,Email,ENT ID,Role,Password\n'
        'Sarra Mansouri,Sarra.Mansouri@Campus.test,221jmt0101,Teacher,Secret-123\n',
      );

      expect(p.isUsable, isTrue);
      expect(p.problems, isEmpty);
      final row = p.rows.single;
      expect(row.row, 2);
      expect(row.displayName, 'Sarra Mansouri');
      expect(row.email, 'sarra.mansouri@campus.test');
      expect(row.studentId, '221JMT0101');
      expect(row.role, UserRole.teacher);
      expect(row.password, 'Secret-123');
      expect(row.passwordGenerated, isFalse);
    });

    test('reads French titles, ";" separators, a BOM and first + last names', () {
      final p = _parse(
        '﻿Nom;Prénom;Courriel;Rôle\r\n'
        'Gharbi;Hélène;helene.gharbi@campus.test;étudiante\r\n'
        'Ben Salah;Amira;amira.bensalah@campus.test;Enseignante\r\n',
      );

      expect(p.problems, isEmpty);
      expect(p.rows.map((r) => r.displayName), ['Hélène Gharbi', 'Amira Ben Salah']);
      expect(p.rows.map((r) => r.role), [UserRole.student, UserRole.teacher]);
    });

    test('reads cells pasted from a spreadsheet (tab-separated)', () {
      final p = _parse('Full name\tE-mail\nOmar Ferchichi\tomar@campus.test\n');
      expect(p.rows.single.displayName, 'Omar Ferchichi');
      expect(p.rows.single.email, 'omar@campus.test');
    });

    test('handles quoted cells with separators, line breaks and quotes', () {
      final p = _parse(
        'Name,Email,Password\n'
        '"Mansouri, Sarra",sarra@campus.test,"pa""ss,word"\n'
        '"Omar\nFerchichi",omar@campus.test,long-enough\n'
        'Yasmine Haddad,yasmine@campus.test,long-enough\n',
      );

      expect(p.rows.map((r) => r.displayName), ['Mansouri, Sarra', 'Omar Ferchichi', 'Yasmine Haddad']);
      expect(p.rows.first.password, 'pa"ss,word');
      // The quoted line break makes line 3 two lines long.
      expect(p.rows.map((r) => r.row), [2, 3, 5]);
    });

    test('finds the title line below a heading, and keeps the file line numbers', () {
      final p = _parse(
        'Promotion 2026 – rentrée\n'
        '\n'
        'Name,Email\n'
        'Sarra Mansouri,sarra@campus.test\n'
        ',\n'
        'Omar Ferchichi,omar@campus.test\n',
      );

      expect(p.rows.map((r) => r.row), [4, 6]);
    });

    test('says which required columns are missing', () {
      expect(_parse('Name,Role\nSarra,student\n').missingColumns, ['Email']);
      expect(_parse('Email\nsarra@campus.test\n').missingColumns, ['Name']);
      expect(_parse('a,b\n1,2\n').missingColumns, ['Name', 'Email']);
    });

    test('refuses empty files and files over $maxImportLines lines', () {
      expect(_parse('').error, 'This file has no accounts.');
      expect(_parse('Name,Email\n\n').error, 'This file has no accounts.');

      final big = StringBuffer('Name,Email\n');
      for (var i = 0; i <= maxImportLines; i++) {
        big.writeln('User $i,user$i@campus.test');
      }
      expect(_parse(big.toString()).error, 'This file has 1001 accounts: at most 1000 per import.');
    });
  });

  group('roles', () {
    test('recognise English and French names and synonyms', () {
      expect(roleFromCell('Student'), UserRole.student);
      expect(roleFromCell('Élève'), UserRole.student);
      expect(roleFromCell('prof'), UserRole.teacher);
      expect(roleFromCell('ADMINISTRATEUR'), UserRole.admin);
      expect(roleFromCell('Diplômé'), UserRole.alumni);
      expect(roleFromCell('Company'), UserRole.company);
      expect(roleFromCell('Société'), UserRole.company);
      expect(roleFromCell('recruteuse'), UserRole.company);
      expect(roleFromCell('Partenaire'), UserRole.company);
      expect(roleFromCell('boss'), isNull);
    });

    test('an empty role is Student, an unknown one is a problem', () {
      final p = _parse('Name,Email,Role\nA B,a@campus.test,\nC D,c@campus.test,boss\n');
      expect(p.rows.first.role, UserRole.student);
      expect(p.rows.last.role, isNull);
      expect(_codes(p, 3), ['INVALID_ROLE']);
    });
  });

  group('passwords', () {
    test('are generated when the cell is empty, as Xxxx-xxxx-xxxx without look-alikes', () {
      final p = _parse('Name,Email\nSarra Mansouri,sarra@campus.test\n');
      final row = p.rows.single;

      expect(row.passwordGenerated, isTrue);
      expect(row.password, matches(RegExp(r'^[A-HJ-NP-Za-km-z2-9]{4}(-[A-HJ-NP-Za-km-z2-9]{4}){2}$')));
      expect(p.problems, isEmpty);
    });

    test('generatePassword gives a different password each time', () {
      final random = Random(42);
      expect(generatePassword(random), isNot(generatePassword(random)));
    });
  });

  test('flags every problem the server would, with its line', () {
    final p = _parse(
      'Name,Email,ENT ID,Password\n'
      ',missing-name@campus.test,,long-enough\n' // 2
      'No Email,,,long-enough\n' // 3
      'Bad Email,not-an-email,,long-enough\n' // 4
      'First,dup@campus.test,221JMT0001,long-enough\n' // 5
      'Second,DUP@campus.test,221jmt0001,long-enough\n' // 6
      'Short,short@campus.test,X1,short\n' // 7
      '${'N' * 81},long@campus.test,,long-enough\n', // 8
    );

    expect(_codes(p, 2), ['REQUIRED']);
    expect(_codes(p, 3), ['REQUIRED']);
    expect(_codes(p, 4), ['INVALID_EMAIL']);
    expect(_codes(p, 5), isEmpty);
    expect(_codes(p, 6), ['DUPLICATE_EMAIL', 'DUPLICATE_STUDENT_ID']);
    expect(_codes(p, 7), ['INVALID_STUDENT_ID', 'PASSWORD_TOO_SHORT']);
    expect(_codes(p, 8), ['TOO_LONG']);
    expect(
      p.problems.firstWhere((x) => x.row == 6 && x.field == 'email').message,
      'Email: already on another line of the file',
    );
    // Lines with problems are kept, so the review can show them.
    expect(p.rows, hasLength(7));
  });

  test('signInDetails is a spreadsheet-safe, tab-separated sheet', () {
    final text = signInDetails(const [
      ImportRow(
        row: 2,
        displayName: '=HYPERLINK("x")',
        email: 'a@campus.test',
        password: 'Abcd-efgh-jkmn',
        role: UserRole.teacher,
        studentId: '221JMT0101',
      ),
    ]);

    expect(
      const LineSplitter().convert(text),
      [
        'Name\tEmail\tENT ID\tRole\tPassword',
        '\'=HYPERLINK("x")\ta@campus.test\t221JMT0101\tTeacher\tAbcd-efgh-jkmn',
      ],
    );
  });

  group('decodeImportFile', () {
    test('reads UTF-8, and Windows files saved by an old Excel', () {
      expect(decodeImportFile('a.csv', Uint8List.fromList(utf8.encode('Hélène'))), 'Hélène');
      expect(decodeImportFile('a.csv', Uint8List.fromList(latin1.encode('Hélène'))), 'Hélène');
    });

    test('refuses Excel files and files over 5 MB', () {
      expect(
        () => decodeImportFile('list.xlsx', Uint8List(10)),
        throwsA(isA<ImportFileException>()
            .having((e) => e.message, 'message', contains('saved as CSV'))),
      );
      expect(
        () => decodeImportFile('big.csv', Uint8List(maxImportFileBytes + 1)),
        throwsA(isA<ImportFileException>()
            .having((e) => e.message, 'message', 'This file is too big (at most 5 MB).')),
      );
    });
  });
}
