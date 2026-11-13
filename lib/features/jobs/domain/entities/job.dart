import 'job_application.dart';

class MissionItem {
  const MissionItem({required this.title, required this.description});
  final String title;
  final String description;
}

/// An internship / PFE / job offer.
///
/// The seeded catalogue has every field. Offers posted by a company or an
/// admin only have what the form asks for: the other fields are null or
/// empty, and the screens hide what is missing.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.mission,
    this.location = '',
    this.tags = const [],
    this.stipendTnd,
    this.durationMonths,
    this.period = '',
    this.labGroup,
    this.labGroupNote,
    this.workspaceTitle,
    this.workspaceBadges = const [],
    this.missionItems = const [],
    this.matchPercent,
    this.criteria = const [],
    this.skills = const [],
    this.featuredLabel,
    this.hasApplied = false,
    this.applicationStatus,
    this.authorId,
    this.canEdit = false,
  });

  final String id;
  final String title;
  final String company;

  /// '' when the offer doesn't say.
  final String location;

  /// e.g. "PFE 2025", "Hybrid (3 days on-site)", "Coeff PFE 20.0"
  final List<String> tags;
  final int? stipendTnd;
  final int? durationMonths;

  /// e.g. "Feb – Jul 2025"; '' when the offer doesn't say.
  final String period;
  final String? labGroup;
  final String? labGroupNote;
  final String? workspaceTitle;
  final List<String> workspaceBadges;

  /// The description of the offer.
  final String mission;
  final List<MissionItem> missionItems;

  /// The student's profile match; null for offers posted by recruiters.
  final int? matchPercent;
  final List<String> criteria;
  final List<String> skills;

  /// Shown above the title when the offer is featured.
  final String? featuredLabel;

  /// Whether the signed-in student already applied to this offer.
  final bool hasApplied;

  /// Where the signed-in student's application stands; null when they didn't apply.
  final ApplicationStatus? applicationStatus;

  /// The company or admin who posted it; null for the seeded catalogue.
  final String? authorId;

  /// Whether the signed-in user may edit and delete it (its author, or an admin).
  final bool canEdit;

  bool get isFeatured => featuredLabel != null;

  /// "Company · Location", or just the company when there is no location.
  String get companyLine => location.isEmpty ? company : '$company · $location';

  /// This offer with [hasApplied] set to [applied].
  Job withApplied(bool applied) => Job(
        id: id,
        title: title,
        company: company,
        location: location,
        tags: tags,
        stipendTnd: stipendTnd,
        durationMonths: durationMonths,
        period: period,
        labGroup: labGroup,
        labGroupNote: labGroupNote,
        workspaceTitle: workspaceTitle,
        workspaceBadges: workspaceBadges,
        mission: mission,
        missionItems: missionItems,
        matchPercent: matchPercent,
        criteria: criteria,
        skills: skills,
        featuredLabel: featuredLabel,
        hasApplied: applied,
        // Applying starts pending; cancelling clears it.
        applicationStatus: applied ? (applicationStatus ?? ApplicationStatus.pending) : null,
        authorId: authorId,
        canEdit: canEdit,
      );

  String get companyInitials {
    final words = company.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final second = words.length > 1 ? words[1][0] : (words.first.length > 1 ? words.first[1] : '');
    return (words.first[0] + second).toUpperCase();
  }
}
