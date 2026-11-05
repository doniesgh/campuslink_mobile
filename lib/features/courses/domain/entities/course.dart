import '../course_logic.dart';
import 'course_module.dart';
import 'course_resource.dart';

/// Teacher of a course.
class Professor {
  const Professor({
    required this.title,
    required this.name,
    required this.office,
    required this.email,
    this.isOnline = false,
  });

  /// "Prof.", "Dr."
  final String title;

  /// "Ben Ali" (without the title, used for the avatar initials).
  final String name;

  /// "Office Bloc B-114"
  final String office;
  final String email;

  /// Currently available on the campus chat.
  final bool isOnline;

  /// "Prof. Ben Ali"
  String get displayName => '$title $name';
}

/// Next graded quiz of a course.
class CourseQuiz {
  const CourseQuiz({required this.topic, required this.date});

  /// "Arch Microservices"
  final String topic;
  final DateTime date;
}

/// Who is around in the course community right now.
class CourseCommunity {
  const CourseCommunity({required this.onlineCount, this.onlineClassmates = const []});

  /// Classmates of this course online right now.
  final int onlineCount;

  /// Online classmates the student knows (shown as avatars).
  final List<String> onlineClassmates;
}

/// A course the student is enrolled in, with its mastery and resources.
class Course {
  const Course({
    required this.id,
    required this.code,
    required this.location,
    required this.title,
    required this.term,
    required this.track,
    required this.professor,
    required this.modules,
    required this.lecturesHeld,
    required this.lectureCount,
    required this.resources,
    required this.community,
    this.nextQuiz,
    this.isPresent = false,
  });

  /// Same id as the course's sessions in the timetable (e.g. 'genie-logiciel').
  final String id;

  /// "GLA-401"
  final String code;

  /// "Block 2B"
  final String location;

  /// "Génie Logiciel & Architecture"
  final String title;

  /// "Winter Semester"
  final String term;

  /// "Advanced Software Systems Track"
  final String track;
  final Professor professor;

  /// Syllabus, in order.
  final List<CourseModule> modules;

  /// Lectures given so far (including today's), out of [lectureCount].
  final int lecturesHeld;
  final int lectureCount;
  final List<CourseResource> resources;
  final CourseCommunity community;
  final CourseQuiz? nextQuiz;

  /// Attendance logged for the latest session.
  final bool isPresent;

  int get completedModules => modules.where((m) => m.isCompleted).length;

  /// 0..1 share of the course hours mastered.
  double get mastery => masteryRatio(modules);

  int get masteryPercent => (mastery * 100).round();

  CoursePace get pace => coursePace(
        completedModules: completedModules,
        totalModules: modules.length,
        lecturesHeld: lecturesHeld,
        lectureCount: lectureCount,
      );

  Course copyWith({bool? isPresent, List<CourseResource>? resources}) => Course(
        id: id,
        code: code,
        location: location,
        title: title,
        term: term,
        track: track,
        professor: professor,
        modules: modules,
        lecturesHeld: lecturesHeld,
        lectureCount: lectureCount,
        resources: resources ?? this.resources,
        community: community,
        nextQuiz: nextQuiz,
        isPresent: isPresent ?? this.isPresent,
      );

  /// Copy where the assignments listed in [repoUrls] (assignment id -> repo
  /// link) are marked as submitted.
  Course withSubmissions(Map<String, String> repoUrls) {
    if (repoUrls.isEmpty) return this;
    return copyWith(resources: [
      for (final r in resources)
        if (r is AssignmentResource && repoUrls.containsKey(r.id))
          r.copyWith(submittedRepoUrl: repoUrls[r.id])
        else
          r,
    ]);
  }
}
