import 'entities/course.dart';
import 'entities/course_module.dart';

/// Where the student stands compared with the lectures given so far.
enum CoursePace { ahead, onTrack, behind }

/// Hours of the completed modules, and of the whole syllabus.
({int done, int total}) masteryHours(List<CourseModule> modules) {
  var done = 0, total = 0;
  for (final m in modules) {
    total += m.hours;
    if (m.isCompleted) done += m.hours;
  }
  return (done: done, total: total);
}

/// 0..1 share of the course hours covered by completed modules
/// (0 for an empty syllabus).
double masteryRatio(List<CourseModule> modules) {
  final h = masteryHours(modules);
  return h.total <= 0 ? 0 : h.done / h.total;
}

/// After [lecturesHeld] of [lectureCount] lectures, the student is expected
/// to have completed the same share of the [totalModules]. A difference of a
/// full module or more makes them ahead / behind.
CoursePace coursePace({
  required int completedModules,
  required int totalModules,
  required int lecturesHeld,
  required int lectureCount,
}) {
  if (totalModules <= 0 || lectureCount <= 0) return CoursePace.onTrack;
  final expected = totalModules * lecturesHeld.clamp(0, lectureCount) / lectureCount;
  final diff = completedModules - expected;
  if (diff >= 1) return CoursePace.ahead;
  if (diff <= -1) return CoursePace.behind;
  return CoursePace.onTrack;
}

/// Modules split into completed and upcoming ones, each in syllabus order.
({List<CourseModule> completed, List<CourseModule> upcoming}) splitModules(
  List<CourseModule> modules,
) {
  final sorted = [...modules]..sort((a, b) => a.number.compareTo(b.number));
  return (
    completed: [for (final m in sorted) if (m.isCompleted) m],
    upcoming: [for (final m in sorted) if (!m.isCompleted) m],
  );
}

/// First module not completed yet (syllabus order), or null when all are done.
CourseModule? nextModule(List<CourseModule> modules) {
  final upcoming = splitModules(modules).upcoming;
  return upcoming.isEmpty ? null : upcoming.first;
}

/// Calendar days from [now] to [date]: 0 today, 1 tomorrow, negative if past.
int daysUntil(DateTime date, DateTime now) =>
    DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;

/// The course whose id or title is [key] (the timetable links by course
/// title), else the first one; null when there are no courses.
Course? selectCourse(List<Course> courses, String? key) {
  if (courses.isEmpty) return null;
  for (final c in courses) {
    if (c.id == key || c.title == key) return c;
  }
  return courses.first;
}

/// Lab submissions must be an https link to a repository
/// (host + owner + name, e.g. https://github.com/you/docker-lab).
bool isValidRepoUrl(String value) {
  final v = value.trim();
  if (v.isEmpty || v.contains(RegExp(r'\s'))) return false;
  final uri = Uri.tryParse(v);
  if (uri == null || uri.scheme != 'https' || !uri.host.contains('.')) return false;
  return uri.pathSegments.where((s) => s.isNotEmpty).length >= 2;
}
