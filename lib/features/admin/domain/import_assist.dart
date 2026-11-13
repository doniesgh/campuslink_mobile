import 'dart:math';

import '../../auth/domain/entities/user.dart';
import 'search_text.dart';
import 'user_import_parser.dart';

// "Read with AI" on the import screen: when a file doesn't follow the
// template (or some roles can't be read), the server's AI says how it is laid
// out (`POST /admin/users/import/assist`). This file builds what is sent (the
// first lines, emails and passwords masked, and the distinct values of short
// columns) and applies the answer to the whole file, which is then checked
// line by line like any other ([parseImportTable]). Pure functions.

/// Lines of the file sent to the AI (where the parser looks for the titles).
const assistLines = 12;
const _assistColumns = 15;
const _assistCellLength = 80;

/// A column with at most this many different values has them all sent
/// (roles: not names or emails).
const _maxDistinct = 40;

/// What is sent in place of each password cell.
const maskedPassword = '•••';

/// The fields the AI can find, by their API names.
enum AssistField {
  lastName('Last name'),
  firstName('First name'),
  fullName('Full name'),
  email('Email'),
  studentId('ENT ID'),
  role('Role'),
  password('Password');

  const AssistField(this.label);

  final String label;
}

/// Where the family name is in a full name ("BEN ALI Ines" is LAST_FIRST).
enum NameOrder {
  lastFirst('LAST_FIRST', 'family name first'),
  firstLast('FIRST_LAST', 'given name first');

  const NameOrder(this.apiName, this.label);

  final String apiName;
  final String label;

  /// LAST_FIRST unless the API says FIRST_LAST.
  static NameOrder fromApi(Object? value) => value == firstLast.apiName ? firstLast : lastFirst;
}

/// The distinct values of one column.
typedef AssistColumnValues = ({int column, List<String> values});

/// What the AI gets: the first lines (masked) and the values of short columns.
class AssistRequest {
  const AssistRequest({required this.lines, required this.values});

  final List<List<String>> lines;
  final List<AssistColumnValues> values;
}

/// What a role value means for the AI (null: it couldn't tell).
typedef AssistRole = ({String text, UserRole? role});

/// How the AI says the file is laid out (checked by the server).
class AssistMapping {
  const AssistMapping({
    required this.headerRow,
    required this.columns,
    this.nameOrder = NameOrder.lastFirst,
    this.roles = const [],
  });

  /// 1-based line (of the lines sent) holding the titles, 0 when there is none.
  final int headerRow;

  /// The 0-based column of each field found.
  final Map<AssistField, int> columns;
  final NameOrder nameOrder;
  final List<AssistRole> roles;
}

/// `GET /admin/users/import/assist`: whether "Read with AI" can be offered.
class ImportAssistStatus {
  const ImportAssistStatus({required this.available, this.model});

  final bool available;

  /// The model asked first ("anthropic/claude-haiku-5.5"), for the privacy note.
  final String? model;
}

/// The answer of `POST /admin/users/import/assist`.
class ImportAssistAnswer {
  const ImportAssistAnswer({required this.mapping, required this.model});

  final AssistMapping mapping;

  /// The model that answered.
  final String model;
}

final _emailPattern = RegExp(r'''[^\s@,;<>"']+@([^\s@,;<>"']+)''');

/// "ines.benali@esprit.tn" → "i…@esprit.tn": enough to see an email column,
/// not whose it is.
String maskEmails(String value) =>
    value.replaceAllMapped(_emailPattern, (m) => '${m[0]![0]}…@${m[1]}');

final _passwordTitle =
    RegExp(r'^(motdepasse|mdp|password|passwd|pwd|pass|codedacces|codeacces|secret)');

/// Lower case, without accents, letters and digits only.
String _fold(String text) => foldAccents(text).replaceAll(RegExp(r'[^a-z0-9]'), '');

/// What the AI gets for [table]: its first [assistLines] lines (15 cells of
/// 80 characters at most) with emails masked and the cells of password
/// columns replaced by [maskedPassword], and the distinct values of each
/// column that has few of them (roles...). Names and emails of the other
/// lines stay on the device.
///
/// Password columns are found by their title ("Mot de passe", "MDP"...) and
/// masked by position, not by look: "Password1" can be a password.
AssistRequest assistRequest(List<ImportTableLine> table) {
  final all = [
    for (final line in table)
      [
        for (final cell in line.cells.take(_assistColumns))
          cell.trim().substring(0, min(cell.trim().length, _assistCellLength)),
      ],
  ];
  final sample = all.take(assistLines).toList();

  // Password column → the line of its title (the only cell left as it is).
  final secret = <int, int>{};
  for (var line = 0; line < sample.length; line++) {
    for (var column = 0; column < sample[line].length; column++) {
      if (!secret.containsKey(column) && _passwordTitle.hasMatch(_fold(sample[line][column]))) {
        secret[column] = line;
      }
    }
  }
  String hide(String value, int column, int line) =>
      secret.containsKey(column) && value.isNotEmpty && secret[column] != line
          ? maskedPassword
          : maskEmails(value);

  final lines = [
    for (var line = 0; line < sample.length; line++)
      [for (var column = 0; column < sample[line].length; column++) hide(sample[line][column], column, line)],
  ];

  final limit = min(_maxDistinct, max(5, all.length ~/ 3));
  final width = all.fold(0, (w, cells) => max(w, cells.length));
  final values = <AssistColumnValues>[];
  for (var column = 0; column < width; column++) {
    if (secret.containsKey(column)) continue;
    final distinct = {
      for (final cells in all)
        if (column < cells.length && cells[column].isNotEmpty) cells[column],
    }.toList();
    if (distinct.isEmpty || distinct.length > limit || distinct.any((v) => v.contains('@'))) {
      continue;
    }
    values.add((column: column, values: distinct));
  }
  return AssistRequest(lines: lines, values: values);
}

/// Particles that belong to the family name: "Ben Ali", "El Amri", "De la Fontaine".
const _particles = {
  'ben', 'bent', 'bin', 'ibn', 'bel', 'bou', 'abou', 'abu', 'ould', 'el', 'al', 'de', 'du',
  'des', 'la', 'le', 'van', 'von', 'der', 'da', 'di',
};

bool _isParticle(String word) => _particles.contains(_fold(word));

final _upperLetter = RegExp(r'\p{Lu}', unicode: true);
final _notLetter = RegExp(r'[^\p{L}]', unicode: true);

/// A word written in capitals ("BEN", "ALI", "N'DIAYE"): a family name in many lists.
bool _isCapitals(String word) =>
    _upperLetter.hasMatch(word) &&
    word == word.toUpperCase() &&
    word.replaceAll(_notLetter, '').length > 1;

/// Splits a full name. The words in capitals are the family name ("BEN ALI
/// Ines", "Ines BEN ALI"); otherwise the first ([NameOrder.lastFirst]) or
/// last ([NameOrder.firstLast]) word, with the particles next to it ("Ben Ali
/// Ines", "Ines Ben Ali").
({String lastName, String firstName}) splitFullName(String fullName, NameOrder order) {
  final words = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < 2) return (lastName: words.isEmpty ? '' : words.first, firstName: '');

  final capitals = words.map(_isCapitals).toList();
  if (capitals.contains(true) && capitals.contains(false)) {
    return (
      lastName: [for (var i = 0; i < words.length; i++) if (capitals[i]) words[i]].join(' '),
      firstName: [for (var i = 0; i < words.length; i++) if (!capitals[i]) words[i]].join(' '),
    );
  }
  if (order == NameOrder.lastFirst) {
    var end = 1;
    while (end < words.length - 1 && _isParticle(words[end - 1])) {
      end++;
    }
    return (lastName: words.sublist(0, end).join(' '), firstName: words.sublist(end).join(' '));
  }
  var start = words.length - 1;
  while (start > 1 && _isParticle(words[start - 1])) {
    start--;
  }
  return (lastName: words.sublist(start).join(' '), firstName: words.sublist(0, start).join(' '));
}

/// The titles [parseImportTable] reads, in the order of the rewritten cells.
const assistTitles = ['First name', 'Last name', 'Email', 'ENT ID', 'Role', 'Password'];

/// [table] rewritten as the template using [mapping]: the AI's title line
/// replaced by [assistTitles] (or those added on top, as line 0), lines above
/// it dropped, full names split ("BEN ALI Ines" → Ines / BEN ALI, so the name
/// becomes "Ines BEN ALI") and role values replaced by the role they mean.
/// Line numbers stay those of the file. [parseImportTable] then checks every
/// line as usual.
List<ImportTableLine> applyAssist(List<ImportTableLine> table, AssistMapping mapping) {
  final columns = mapping.columns;
  String get(List<String> cells, AssistField field) {
    final index = columns[field];
    return index == null || index >= cells.length ? '' : cells[index].trim();
  }

  final roles = {for (final r in mapping.roles) r.text: r.role};
  List<String> rewrite(List<String> cells) {
    var lastName = get(cells, AssistField.lastName);
    var firstName = get(cells, AssistField.firstName);
    if (columns.containsKey(AssistField.fullName)) {
      final split = splitFullName(get(cells, AssistField.fullName), mapping.nameOrder);
      if (lastName.isEmpty) lastName = split.lastName;
      if (firstName.isEmpty) firstName = split.firstName;
    }
    final role = get(cells, AssistField.role);
    return [
      firstName,
      lastName,
      get(cells, AssistField.email),
      get(cells, AssistField.studentId),
      roles[role]?.name ?? role,
      get(cells, AssistField.password),
    ];
  }

  final header = mapping.headerRow;
  if (header > 0 && header <= table.length) {
    return [
      for (final (i, line) in table.indexed)
        if (i == header - 1)
          (line: line.line, cells: assistTitles)
        else if (i >= header)
          (line: line.line, cells: rewrite(line.cells)),
    ];
  }
  return [
    (line: 0, cells: assistTitles),
    for (final line in table) (line: line.line, cells: rewrite(line.cells)),
  ];
}

/// "A", "B", ... "Z", "AA": a column as a spreadsheet names it.
String columnLetter(int index) {
  var letter = '';
  for (var rest = index + 1; rest > 0; rest = (rest - 1) ~/ 26) {
    letter = String.fromCharCode(65 + (rest - 1) % 26) + letter;
  }
  return letter;
}
