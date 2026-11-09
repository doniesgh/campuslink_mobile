const _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'ç': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'œ': 'oe', 'æ': 'ae',
};

/// Lower case without accents: "Hélène" → "helene". Used to compare names
/// the way the server does (case and accents ignored).
String foldAccents(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// True when every word of [query] appears in one of [fields], ignoring case
/// and accents (the rule of `GET /admin/users?q=`).
bool matchesEveryWord(String query, Iterable<String?> fields) {
  final haystack = [for (final f in fields) if (f != null) foldAccents(f)];
  return foldAccents(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .every((word) => haystack.any((field) => field.contains(word)));
}
