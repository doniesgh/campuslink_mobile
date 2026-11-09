import 'dart:math';

import '../../auth/domain/entities/user.dart';
import 'entities/user_import.dart';
import 'search_text.dart';

/// At most this many lines per file (the server checks up to 1000 at once).
const maxImportLines = 1000;

/// Accounts sent per import request (the server accepts at most 50).
const importBatchSize = 25;

/// The columns an import file can have.
enum ImportColumn {
  name('Name'),
  firstName('First name'),
  lastName('Last name'),
  email('Email'),
  studentId('ENT ID'),
  role('Role'),
  password('Password');

  const ImportColumn(this.label);

  final String label;
}

/// A file read by [parseUserImport].
class ParsedImport {
  const ParsedImport({
    this.rows = const [],
    this.problems = const [],
    this.missingColumns = const [],
    this.error,
  });

  /// Every account line, problems or not, in file order.
  final List<ImportRow> rows;

  /// Problems found on this device (the server adds its own, such as
  /// `EMAIL_TAKEN`, during the check).
  final List<ImportProblem> problems;

  /// Required columns that weren't found ("Name", "Email").
  final List<String> missingColumns;

  /// Why the whole file can't be used ("This file has no accounts."), or null.
  final String? error;

  bool get isUsable => error == null && missingColumns.isEmpty;
}

/// Reads an export of a spreadsheet: CSV (`,` or `;`) or cells pasted from
/// Excel / Google Sheets (tab-separated).
///
/// - The title line is whichever of the first 12 lines has the most known
///   titles, in English or French ("Nom", "Prénom", "Courriel", "Rôle"...).
/// - Required: an email column, and a name column or first/last name columns.
/// - An empty role is Student. An empty password is generated with [random].
/// - Line numbers are those of the file, so the admin can find them.
ParsedImport parseUserImport(String text, {Random? random}) {
  final records = _readRecords(text.replaceFirst('﻿', ''));
  final nonEmpty = records.where((r) => !r.isBlank).toList();
  if (nonEmpty.isEmpty) return const ParsedImport(error: 'This file has no accounts.');

  final header = _findHeader(nonEmpty.take(12).toList());
  if (header == null) {
    return const ParsedImport(missingColumns: ['Name', 'Email']);
  }
  final columns = header.columns;
  final hasName = columns.containsKey(ImportColumn.name) ||
      columns.containsKey(ImportColumn.firstName) ||
      columns.containsKey(ImportColumn.lastName);
  final missing = [
    if (!hasName) 'Name',
    if (!columns.containsKey(ImportColumn.email)) 'Email',
  ];
  if (missing.isNotEmpty) return ParsedImport(missingColumns: missing);

  final lines = nonEmpty.where((r) => r.line > header.record.line).toList();
  if (lines.isEmpty) return const ParsedImport(error: 'This file has no accounts.');
  if (lines.length > maxImportLines) {
    return ParsedImport(
      error: 'This file has ${lines.length} accounts: at most $maxImportLines per import.',
    );
  }

  final rng = random ?? Random.secure();
  final rows = <ImportRow>[];
  final problems = <ImportProblem>[];
  final seenEmails = <String>{};
  final seenStudentIds = <String>{};

  for (final record in lines) {
    String cell(ImportColumn c) {
      final index = columns[c];
      return index == null || index >= record.cells.length ? '' : record.cells[index].trim();
    }

    final row = record.line;
    void problem(String field, String code, String message) =>
        problems.add(ImportProblem(row: row, field: field, code: code, message: message));

    final name = _collapseSpaces(
      columns.containsKey(ImportColumn.name)
          ? cell(ImportColumn.name)
          : '${cell(ImportColumn.firstName)} ${cell(ImportColumn.lastName)}',
    );
    final email = cell(ImportColumn.email).toLowerCase();
    final studentId = cell(ImportColumn.studentId).toUpperCase();
    final roleCell = cell(ImportColumn.role);
    final role = roleCell.isEmpty ? UserRole.student : roleFromCell(roleCell);
    var password = cell(ImportColumn.password);
    final generated = password.isEmpty;
    if (generated) password = generatePassword(rng);

    if (name.isEmpty) {
      problem('displayName', 'REQUIRED', 'Name: missing');
    } else if (name.length > 80) {
      problem('displayName', 'TOO_LONG', 'Name: too long (at most 80 characters)');
    }
    if (email.isEmpty) {
      problem('email', 'REQUIRED', 'Email: missing');
    } else if (!_email.hasMatch(email)) {
      problem('email', 'INVALID_EMAIL', 'Email: not a valid address');
    } else if (!seenEmails.add(email)) {
      problem('email', 'DUPLICATE_EMAIL', 'Email: already on another line of the file');
    }
    if (studentId.isNotEmpty) {
      if (!_studentId.hasMatch(studentId)) {
        problem('studentId', 'INVALID_STUDENT_ID', 'ENT ID: 3 to 20 letters or digits');
      } else if (!seenStudentIds.add(studentId)) {
        problem(
          'studentId',
          'DUPLICATE_STUDENT_ID',
          'ENT ID: already on another line of the file',
        );
      }
    }
    if (role == null) {
      problem('role', 'INVALID_ROLE', 'Role: not recognised (student, teacher, admin or alumni)');
    }
    if (password.length < 8) {
      problem('password', 'PASSWORD_TOO_SHORT', 'Password: at least 8 characters');
    }

    rows.add(ImportRow(
      row: row,
      displayName: name,
      email: email,
      password: password,
      role: role,
      studentId: studentId.isEmpty ? null : studentId,
      passwordGenerated: generated,
    ));
  }
  return ParsedImport(rows: rows, problems: problems);
}

/// The role written in a cell: its English or French name, or a common
/// synonym ("prof", "étudiant", "diplômé"...). Null when not recognised.
UserRole? roleFromCell(String text) {
  final key = _fold(text);
  for (final MapEntry(key: role, value: aliases) in _roleAliases.entries) {
    if (aliases.contains(key)) return role;
  }
  return null;
}

/// A password for an account whose line had none: 12 characters without
/// look-alikes (no 0/O, 1/l/I), written `Xxxx-xxxx-xxxx` to be easy to read out.
String generatePassword(Random random) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  String group() =>
      String.fromCharCodes(List.generate(4, (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length))));
  return '${group()}-${group()}-${group()}';
}

/// The sign-in details of [rows], tab-separated with a title line, ready to
/// paste into a spreadsheet.
String signInDetails(List<ImportRow> rows) {
  final buffer = StringBuffer('Name\tEmail\tENT ID\tRole\tPassword\n');
  for (final r in rows) {
    buffer.writeln(
      [r.displayName, r.email, r.studentId ?? '', (r.role ?? UserRole.student).label, r.password]
          .map(_spreadsheetSafe)
          .join('\t'),
    );
  }
  return buffer.toString();
}

/// The template's title line, shown to the admin.
const importTemplateHeader = 'Name,Email,ENT ID,Role,Password';

// ---------------------------------------------------------------------------

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _studentId = RegExp(r'^[A-Z0-9]{3,20}$');

/// Known titles of each column, folded (see [_fold]).
const _headerAliases = <ImportColumn, Set<String>>{
  ImportColumn.name: {
    'name', 'fullname', 'displayname', 'nomcomplet', 'nometprenom', 'prenometnom',
    'nomprenom', 'prenomnom',
  },
  ImportColumn.firstName: {'firstname', 'givenname', 'first', 'prenom', 'prenoms'},
  ImportColumn.lastName: {'lastname', 'surname', 'familyname', 'last', 'nom', 'nomdefamille'},
  ImportColumn.email: {
    'email', 'mail', 'emailaddress', 'courriel', 'adresseemail', 'adressemail',
    'adressecourriel', 'adresseelectronique',
  },
  ImportColumn.studentId: {
    'entid', 'ent', 'studentid', 'matricule', 'identifiant', 'identifiantent',
    'numeroetudiant', 'idetudiant',
  },
  ImportColumn.role: {'role', 'profil', 'profile', 'type', 'statut', 'status'},
  ImportColumn.password: {'password', 'motdepasse', 'mdp', 'pwd'},
};

const _roleAliases = <UserRole, Set<String>>{
  UserRole.student: {'student', 'etudiant', 'etudiante', 'eleve', 'etu'},
  UserRole.teacher: {
    'teacher', 'enseignant', 'enseignante', 'prof', 'professeur', 'professor',
    'formateur', 'formatrice',
  },
  UserRole.admin: {'admin', 'administrateur', 'administratrice', 'administrator'},
  UserRole.alumni: {
    'alumni', 'alumnus', 'alumna', 'diplome', 'diplomee', 'ancien', 'ancienne',
    'ancienetudiant',
  },
};

/// Lower case, without accents, letters and digits only: "Prénom(s)" → "prenoms".
String _fold(String text) => foldAccents(text).replaceAll(RegExp(r'[^a-z0-9]'), '');

String _collapseSpaces(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');

/// A spreadsheet would run a cell starting with = + - @ as a formula.
String _spreadsheetSafe(String value) {
  final clean = value.replaceAll(RegExp(r'[\t\r\n]'), ' ');
  return RegExp(r'^[=+\-@]').hasMatch(clean) ? "'$clean" : clean;
}

class _Record {
  _Record(this.line, this.cells);

  /// 1-based line where the record starts.
  final int line;
  final List<String> cells;

  bool get isBlank => cells.every((c) => c.trim().isEmpty);
}

class _Header {
  _Header(this.record, this.columns);

  final _Record record;

  /// Column → cell index.
  final Map<ImportColumn, int> columns;
}

_Header? _findHeader(List<_Record> candidates) {
  _Header? best;
  for (final record in candidates) {
    final columns = <ImportColumn, int>{};
    for (var i = 0; i < record.cells.length; i++) {
      final key = _fold(record.cells[i]);
      for (final MapEntry(key: column, value: aliases) in _headerAliases.entries) {
        if (aliases.contains(key) && !columns.containsKey(column)) {
          columns[column] = i;
          break;
        }
      }
    }
    if (columns.isNotEmpty && (best == null || columns.length > best.columns.length)) {
      best = _Header(record, columns);
    }
  }
  return best;
}

/// The separator used by the first line: tab, `;` or `,` (outside quotes).
String _detectSeparator(String text) {
  var tabs = 0, semicolons = 0, commas = 0;
  var quoted = false;
  for (final char in text.split('')) {
    if (char == '"') quoted = !quoted;
    if (quoted) continue;
    if (char == '\n' || char == '\r') break;
    if (char == '\t') tabs++;
    if (char == ';') semicolons++;
    if (char == ',') commas++;
  }
  if (tabs >= semicolons && tabs >= commas && tabs > 0) return '\t';
  if (semicolons >= commas && semicolons > 0) return ';';
  return ',';
}

/// Splits [text] into records (RFC 4180: quoted cells may hold separators,
/// line breaks and `""` for a quote).
List<_Record> _readRecords(String text) {
  final firstLine = text.trimLeft();
  final separator = _detectSeparator(firstLine);
  final records = <_Record>[];
  var cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var line = 1;
  var recordLine = 1;

  void endCell() {
    cells.add(cell.toString());
    cell.clear();
  }

  void endRecord() {
    endCell();
    records.add(_Record(recordLine, cells));
    cells = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        if (char == '\n') line++;
        cell.write(char);
      }
      continue;
    }
    if (char == '"' && cell.isEmpty) {
      quoted = true;
    } else if (char == separator) {
      endCell();
    } else if (char == '\r' || char == '\n') {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRecord();
      line++;
      recordLine = line;
    } else {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || cells.isNotEmpty) endRecord();
  return records;
}
