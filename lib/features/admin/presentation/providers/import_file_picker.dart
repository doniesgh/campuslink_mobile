import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A text file chosen by the admin.
typedef PickedTextFile = ({String name, String text});

/// Files bigger than this are refused (1000 lines are far smaller).
const maxImportFileBytes = 5 * 1024 * 1024;

/// Why a chosen file can't be read. [message] is shown to the admin.
class ImportFileException implements Exception {
  const ImportFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Opens the system file picker on CSV files. Overridden in tests.
final importFilePickerProvider =
    Provider<Future<PickedTextFile?> Function()>((ref) => pickImportFile);

/// The chosen CSV file as text, or null when the admin cancelled.
/// Throws [ImportFileException] for files that can't be used.
Future<PickedTextFile?> pickImportFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'tsv', 'txt'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  if (file == null) return null;
  final bytes = file.bytes;
  if (bytes == null) throw const ImportFileException("This file can't be read. Choose a CSV file.");
  return (name: file.name, text: decodeImportFile(file.name, bytes));
}

/// The text of an import file: UTF-8, or Windows-1252 for files saved by an
/// old Excel ("Hélène" would otherwise come out broken).
@visibleForTesting
String decodeImportFile(String name, Uint8List bytes) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
    throw const ImportFileException(
      'Excel files must be saved as CSV first (File › Save as › CSV UTF-8), '
      'or copy the cells and paste them below.',
    );
  }
  if (bytes.length > maxImportFileBytes) {
    throw const ImportFileException('This file is too big (at most 5 MB).');
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}
