import '../../domain/entities/job.dart';
import '../../domain/entities/job_draft.dart';
import '../../domain/entities/job_summary.dart';

/// Backend offer JSON (GET /jobs, GET /jobs/:id, POST /jobs, PATCH /jobs/:id):
/// { "id": "instadeep-ml", "featuredLabel": "FEATURED RESEARCH OPENING" | null,
///   "title": "...", "company": "...", "location": "..." | "", "tags": [...],
///   "stipendTnd": 1200 | null, "durationMonths": 6 | null, "period": "Feb – Jul 2025" | "",
///   "labGroup": "..." | null, "labGroupNote": "..." | null, "workspaceTitle": "..." | null,
///   "workspaceBadges": [...], "mission": "...", "description": "...same as mission...",
///   "missionItems": [{ "title": "...", "description": "..." }],
///   "matchPercent": 94 | null, "criteria": [...], "skills": [...],
///   "hasApplied": false,            // for the signed-in student
///   "authorId": "..." | null,       // null for the seeded catalogue
///   "canEdit": false }              // its author or an admin
///
/// Posted offers leave the rich fields null or empty; old API versions had
/// no `authorId` / `canEdit`. Both read fine.
abstract final class JobModel {
  static Job fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        featuredLabel: json['featuredLabel'] as String?,
        title: json['title'] as String,
        company: json['company'] as String,
        location: json['location'] as String? ?? '',
        tags: _strings(json['tags']),
        stipendTnd: (json['stipendTnd'] as num?)?.toInt(),
        durationMonths: (json['durationMonths'] as num?)?.toInt(),
        period: json['period'] as String? ?? '',
        labGroup: _text(json['labGroup']),
        labGroupNote: _text(json['labGroupNote']),
        workspaceTitle: _text(json['workspaceTitle']),
        workspaceBadges: _strings(json['workspaceBadges']),
        mission: json['mission'] as String? ?? json['description'] as String? ?? '',
        missionItems: [
          for (final item in (json['missionItems'] as List<dynamic>?) ?? const [])
            MissionItem(
              title: (item as Map<String, dynamic>)['title'] as String,
              description: item['description'] as String,
            ),
        ],
        matchPercent: (json['matchPercent'] as num?)?.toInt(),
        criteria: _strings(json['criteria']),
        skills: _strings(json['skills']),
        hasApplied: json['hasApplied'] as bool? ?? false,
        authorId: json['authorId'] as String?,
        canEdit: json['canEdit'] as bool? ?? false,
      );

  static List<Job> listFromJson(List<dynamic> json) =>
      [for (final job in json) fromJson(job as Map<String, dynamic>)];

  static List<String> _strings(Object? json) =>
      [for (final s in (json as List<dynamic>?) ?? const []) s as String];

  /// null for a missing or blank text.
  static String? _text(Object? json) {
    final s = json as String?;
    return s == null || s.trim().isEmpty ? null : s;
  }
}

/// Body of POST /jobs and PATCH /jobs/:id. Every field is sent, so an edit
/// also clears what was emptied (null clears a number).
abstract final class JobDraftModel {
  static Map<String, dynamic> toJson(JobDraft draft) => {
        'title': draft.title.trim(),
        'company': draft.company.trim(),
        'description': draft.description.trim(),
        'location': draft.location.trim(),
        'period': draft.period.trim(),
        'durationMonths': draft.durationMonths,
        'stipendTnd': draft.stipendTnd,
        'skills': draft.skills,
        'tags': draft.tags,
      };
}

/// POST /jobs/:id/summary:
/// { "summary": "...", "keyPoints": [...], "skills": [...], "idealFor": "...",
///   "model": "...", "cached": false }
abstract final class JobSummaryModel {
  static JobSummary fromJson(Map<String, dynamic> json) => JobSummary(
        summary: json['summary'] as String,
        keyPoints: JobModel._strings(json['keyPoints']),
        skills: JobModel._strings(json['skills']),
        idealFor: json['idealFor'] as String? ?? '',
        model: json['model'] as String? ?? '',
        cached: json['cached'] as bool? ?? false,
      );
}
