/// "Dony Ben Salem" -> "DB", "dony" -> "D", "" -> "?"
/// (same rule as the shared UserAvatar, used for the rectangular ID photo).
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final second = parts.length > 1 ? parts[1][0] : '';
  return (parts.first[0] + second).toUpperCase();
}
