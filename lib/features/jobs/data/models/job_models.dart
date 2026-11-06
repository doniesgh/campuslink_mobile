import '../../domain/entities/job.dart';

/// Backend offer JSON (GET /jobs, GET /jobs/:id):
/// { "id": "instadeep-ml", "featuredLabel": "FEATURED RESEARCH OPENING" | null,
///   "title": "...", "company": "...", "location": "...", "tags": [...],
///   "stipendTnd": 1200, "durationMonths": 6, "period": "Feb – Jul 2025",
///   "labGroup": "...", "labGroupNote": "...", "workspaceTitle": "...",
///   "workspaceBadges": [...], "mission": "...",
///   "missionItems": [{ "title": "...", "description": "..." }],
///   "matchPercent": 94, "criteria": [...], "skills": [...],
///   "hasApplied": false }   // for the signed-in student
abstract final class JobModel {
  static Job fromJson(Map<String, dynamic> json) => Job(
        id: json['id'] as String,
        featuredLabel: json['featuredLabel'] as String?,
        title: json['title'] as String,
        company: json['company'] as String,
        location: json['location'] as String,
        tags: _strings(json['tags']),
        stipendTnd: (json['stipendTnd'] as num).toInt(),
        durationMonths: (json['durationMonths'] as num).toInt(),
        period: json['period'] as String,
        labGroup: json['labGroup'] as String,
        labGroupNote: json['labGroupNote'] as String,
        workspaceTitle: json['workspaceTitle'] as String,
        workspaceBadges: _strings(json['workspaceBadges']),
        mission: json['mission'] as String,
        missionItems: [
          for (final item in (json['missionItems'] as List<dynamic>?) ?? const [])
            MissionItem(
              title: (item as Map<String, dynamic>)['title'] as String,
              description: item['description'] as String,
            ),
        ],
        matchPercent: (json['matchPercent'] as num).toInt(),
        criteria: _strings(json['criteria']),
        skills: _strings(json['skills']),
        hasApplied: json['hasApplied'] as bool? ?? false,
      );

  static List<Job> listFromJson(List<dynamic> json) =>
      [for (final job in json) fromJson(job as Map<String, dynamic>)];

  static List<String> _strings(Object? json) =>
      [for (final s in (json as List<dynamic>?) ?? const []) s as String];
}
