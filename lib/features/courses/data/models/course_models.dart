import '../../domain/entities/course.dart';
import '../../domain/entities/course_module.dart';
import '../../domain/entities/course_resource.dart';

// JSON from the courses API (backend/src/modules/courses). Instants are
// ISO-8601 UTC strings, shown in the phone's local time.

DateTime _instant(Object? value) => DateTime.parse(value as String).toLocal();

/// Expected course JSON (abridged):
/// { "id": "genie-logiciel", "code": "GLA-401", "location": "...", "title": "...",
///   "term": "...", "track": "...", "professor": {...}, "modules": [...],
///   "lecturesHeld": 7, "lectureCount": 14,
///   "nextQuiz": { "topic": "...", "date": "2026-11-09T09:15:00.000Z" } | null,
///   "resources": [...], "community": { "onlineCount": 24, "onlineClassmates": [...] },
///   "isPresent": true }
Course courseFromJson(Map<String, dynamic> json) {
  final quiz = json['nextQuiz'] as Map<String, dynamic>?;
  final community = json['community'] as Map<String, dynamic>;
  return Course(
    id: json['id'] as String,
    code: json['code'] as String,
    location: json['location'] as String,
    title: json['title'] as String,
    term: json['term'] as String,
    track: json['track'] as String,
    professor: professorFromJson(json['professor'] as Map<String, dynamic>),
    modules: [
      for (final m in json['modules'] as List) courseModuleFromJson(m as Map<String, dynamic>),
    ],
    lecturesHeld: (json['lecturesHeld'] as num).toInt(),
    lectureCount: (json['lectureCount'] as num).toInt(),
    nextQuiz: quiz == null
        ? null
        : CourseQuiz(topic: quiz['topic'] as String, date: _instant(quiz['date'])),
    resources: [
      for (final r in json['resources'] as List) courseResourceFromJson(r as Map<String, dynamic>),
    ].nonNulls.toList(),
    community: CourseCommunity(
      onlineCount: (community['onlineCount'] as num).toInt(),
      onlineClassmates: [
        for (final name in (community['onlineClassmates'] as List?) ?? const []) name as String,
      ],
    ),
    isPresent: (json['isPresent'] as bool?) ?? false,
  );
}

/// { "title": "Prof.", "name": "Ben Ali", "office": "...", "email": "...", "isOnline": true }
Professor professorFromJson(Map<String, dynamic> json) => Professor(
      title: json['title'] as String,
      name: json['name'] as String,
      office: json['office'] as String,
      email: json['email'] as String,
      isOnline: (json['isOnline'] as bool?) ?? false,
    );

/// { "number": 1, "title": "...", "hours": 3, "isCompleted": true }
CourseModule courseModuleFromJson(Map<String, dynamic> json) => CourseModule(
      number: (json['number'] as num).toInt(),
      title: json['title'] as String,
      hours: (json['hours'] as num).toInt(),
      isCompleted: (json['isCompleted'] as bool?) ?? false,
    );

/// A resource, by its "type":
/// - document: { "id", "title", "format", "sizeBytes", "updatedAt" (instant) }
/// - video: { "id", "title", "durationSeconds", "quality" }
/// - assignment: { "id", "title", "description", "dueAt" (instant), "points",
///   "isMandatory", "submittedRepoUrl": "https://..." | null }
///
/// Null for a type this version of the app does not know (it is skipped).
CourseResource? courseResourceFromJson(Map<String, dynamic> json) {
  final id = json['id'] as String;
  final title = json['title'] as String;
  switch (json['type']) {
    case 'document':
      return DocumentResource(
        id: id,
        title: title,
        format: json['format'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        updatedAt: _instant(json['updatedAt']),
      );
    case 'video':
      return VideoResource(
        id: id,
        title: title,
        duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
        quality: json['quality'] as String,
      );
    case 'assignment':
      return AssignmentResource(
        id: id,
        title: title,
        description: json['description'] as String,
        dueAt: _instant(json['dueAt']),
        points: (json['points'] as num).toInt(),
        isMandatory: (json['isMandatory'] as bool?) ?? true,
        submittedRepoUrl: json['submittedRepoUrl'] as String?,
      );
    default:
      return null;
  }
}
