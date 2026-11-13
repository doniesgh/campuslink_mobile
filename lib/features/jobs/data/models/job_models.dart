import '../../domain/entities/job.dart';
import '../../domain/entities/job_application.dart';
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
///   "applicationStatus": null | "pending" | "accepted" | "rejected",
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
        applicationStatus: ApplicationStatus.tryParse(json['applicationStatus']),
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

/// Application JSON, in the two shapes of the API:
/// GET /jobs/applications/mine (student):
/// { "id", "jobId", "status", "appliedAt", "decidedAt": null | "...",
///   "job": { "id", "title", "company", "location" } }
/// GET /jobs/:id/applications and PATCH /jobs/:id/applications/:applicationId (company):
/// { "id", "jobId", "status", "appliedAt", "decidedAt",
///   "applicant": { "id", "displayName", "email" } }
abstract final class JobApplicationModel {
  static JobApplication fromJson(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>?;
    final applicant = json['applicant'] as Map<String, dynamic>?;
    final decidedAt = json['decidedAt'] as String?;
    return JobApplication(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      status: ApplicationStatus.tryParse(json['status']) ?? ApplicationStatus.pending,
      appliedAt: DateTime.parse(json['appliedAt'] as String).toLocal(),
      decidedAt: decidedAt == null ? null : DateTime.parse(decidedAt).toLocal(),
      jobTitle: job?['title'] as String? ?? '',
      company: job?['company'] as String? ?? '',
      location: job?['location'] as String? ?? '',
      applicantName: applicant?['displayName'] as String? ?? '',
      applicantEmail: applicant?['email'] as String? ?? '',
    );
  }

  static List<JobApplication> listFromJson(List<dynamic> json) =>
      [for (final item in json) fromJson(item as Map<String, dynamic>)];
}
