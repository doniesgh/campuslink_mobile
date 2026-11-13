/// Rules of a posted offer. They are the server's rules, with the same
/// messages: backend/src/modules/jobs/jobs.schemas.ts. Change both together.
///
/// Each check takes the text of a form field and returns the message to
/// show, or null when the value is valid.
abstract final class JobFormRules {
  static const titleMin = 3;
  static const titleMax = 120;
  static const companyMin = 2;
  static const companyMax = 100;
  static const locationMax = 100;
  static const periodMax = 60;
  static const descriptionMin = 20;
  static const descriptionMax = 5000;
  static const durationMax = 36;
  static const stipendMax = 100000;
  static const listItemMax = 40;
  static const skillsMax = 15;
  static const tagsMax = 6;

  static const durationMessage =
      'The duration is a whole number of months, from 1 to $durationMax.';
  static const stipendMessage = 'The stipend is a whole number of TND, from 0 to $stipendMax.';
  static const skillsMessage = 'At most $skillsMax skills, of $listItemMax characters each.';
  static const tagsMessage = 'At most $tagsMax tags, of $listItemMax characters each.';

  static String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a title.';
    if (v.length < titleMin) return 'The title needs at least $titleMin characters.';
    if (v.length > titleMax) return 'The title can have at most $titleMax characters.';
    return null;
  }

  /// Required in the form (the API would use the author's name).
  static String? company(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < companyMin) return 'The company name needs at least $companyMin characters.';
    if (v.length > companyMax) return 'The company name can have at most $companyMax characters.';
    return null;
  }

  static String? location(String? value) => (value?.trim().length ?? 0) > locationMax
      ? 'The location can have at most $locationMax characters.'
      : null;

  static String? period(String? value) => (value?.trim().length ?? 0) > periodMax
      ? 'The period can have at most $periodMax characters.'
      : null;

  static String? description(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a description.';
    if (v.length < descriptionMin) {
      return 'The description needs at least $descriptionMin characters.';
    }
    if (v.length > descriptionMax) {
      return 'The description can have at most $descriptionMax characters.';
    }
    return null;
  }

  /// Optional: empty is fine.
  static String? durationMonths(String? value) =>
      _wholeNumber(value, 1, durationMax, durationMessage);

  /// Optional: empty is fine.
  static String? stipendTnd(String? value) => _wholeNumber(value, 0, stipendMax, stipendMessage);

  static String? skills(String? value) => _labels(value, skillsMax, skillsMessage);

  static String? tags(String? value) => _labels(value, tagsMax, tagsMessage);

  /// "Flutter, Dart, , flutter " → ["Flutter", "Dart", "flutter"]: trimmed,
  /// blanks and exact duplicates dropped (as the server does).
  static List<String> splitList(String? value) {
    final items = <String>[];
    for (final part in (value ?? '').split(',')) {
      final item = part.trim();
      if (item.isNotEmpty && !items.contains(item)) items.add(item);
    }
    return items;
  }

  /// The number in [value], or null when it is empty (or not a whole number).
  static int? parseNumber(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : int.tryParse(v);
  }

  static String? _wholeNumber(String? value, int min, int max, String message) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    return n == null || n < min || n > max ? message : null;
  }

  static String? _labels(String? value, int max, String message) {
    final items = splitList(value);
    return items.length > max || items.any((i) => i.length > listItemMax) ? message : null;
  }
}
