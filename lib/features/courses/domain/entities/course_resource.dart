/// Handout, recording or graded lab attached to a course.
sealed class CourseResource {
  const CourseResource({required this.id, required this.title});

  final String id;
  final String title;
}

/// Downloadable file (lesson slides, PDF handouts...).
class DocumentResource extends CourseResource {
  const DocumentResource({
    required super.id,
    required super.title,
    required this.format,
    required this.sizeBytes,
    required this.updatedAt,
  });

  /// "PDF", "PPTX"...
  final String format;
  final int sizeBytes;
  final DateTime updatedAt;
}

/// Recorded lesson, streamed (not downloaded).
class VideoResource extends CourseResource {
  const VideoResource({
    required super.id,
    required super.title,
    required this.duration,
    required this.quality,
  });

  final Duration duration;

  /// "1080p", "720p"...
  final String quality;
}

/// Lab handed in as a Git repository link.
class AssignmentResource extends CourseResource {
  const AssignmentResource({
    required super.id,
    required super.title,
    required this.description,
    required this.dueAt,
    required this.points,
    this.isMandatory = true,
    this.submittedRepoUrl,
  });

  final String description;
  final DateTime dueAt;
  final int points;

  /// Counts in the course grade (otherwise a bonus).
  final bool isMandatory;

  /// Repository handed in by the student, or null when not submitted yet.
  final String? submittedRepoUrl;

  bool get isSubmitted => submittedRepoUrl != null;

  AssignmentResource copyWith({String? submittedRepoUrl}) => AssignmentResource(
        id: id,
        title: title,
        description: description,
        dueAt: dueAt,
        points: points,
        isMandatory: isMandatory,
        submittedRepoUrl: submittedRepoUrl ?? this.submittedRepoUrl,
      );
}
