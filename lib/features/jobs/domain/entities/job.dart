class MissionItem {
  const MissionItem({required this.title, required this.description});
  final String title;
  final String description;
}

class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.tags,
    required this.stipendTnd,
    required this.durationMonths,
    required this.period,
    required this.labGroup,
    required this.labGroupNote,
    required this.workspaceTitle,
    required this.workspaceBadges,
    required this.mission,
    required this.missionItems,
    required this.matchPercent,
    required this.criteria,
    required this.skills,
    this.featuredLabel,
  });

  final String id;
  final String title;
  final String company;
  final String location;

  /// e.g. "PFE 2025", "Hybrid (3 days on-site)", "Coeff PFE 20.0"
  final List<String> tags;
  final int stipendTnd;
  final int durationMonths;
  final String period;
  final String labGroup;
  final String labGroupNote;
  final String workspaceTitle;
  final List<String> workspaceBadges;
  final String mission;
  final List<MissionItem> missionItems;
  final int matchPercent;
  final List<String> criteria;
  final List<String> skills;

  /// Shown above the title when the offer is featured.
  final String? featuredLabel;

  bool get isFeatured => featuredLabel != null;

  String get companyInitials {
    final words = company.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final second = words.length > 1 ? words[1][0] : (words.first.length > 1 ? words.first[1] : '');
    return (words.first[0] + second).toUpperCase();
  }
}
