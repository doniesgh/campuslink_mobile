/// One module (chapter) of a course syllabus.
class CourseModule {
  const CourseModule({
    required this.number,
    required this.title,
    required this.hours,
    this.isCompleted = false,
  });

  /// 1-based position in the syllabus.
  final int number;
  final String title;

  /// Teaching hours. A module weighs its hours in the mastery score.
  final int hours;

  /// Lesson studied and its quiz passed.
  final bool isCompleted;
}
