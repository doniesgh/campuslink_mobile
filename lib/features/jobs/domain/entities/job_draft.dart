import 'job.dart';

/// What the offer form sends (POST /jobs, PATCH /jobs/:id): every field of
/// the form, so an edit also clears what was emptied.
class JobDraft {
  const JobDraft({
    required this.title,
    required this.company,
    required this.description,
    this.location = '',
    this.period = '',
    this.durationMonths,
    this.stipendTnd,
    this.skills = const [],
    this.tags = const [],
  });

  /// The form prefilled with [job].
  factory JobDraft.fromJob(Job job) => JobDraft(
        title: job.title,
        company: job.company,
        description: job.mission,
        location: job.location,
        period: job.period,
        durationMonths: job.durationMonths,
        stipendTnd: job.stipendTnd,
        skills: job.skills,
        tags: job.tags,
      );

  final String title;
  final String company;
  final String description;
  final String location;
  final String period;
  final int? durationMonths;
  final int? stipendTnd;
  final List<String> skills;
  final List<String> tags;
}
