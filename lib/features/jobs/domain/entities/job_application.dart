/// Where an application stands. The company answers a `pending` one.
enum ApplicationStatus {
  pending,
  accepted,
  rejected;

  static ApplicationStatus? tryParse(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return null;
  }

  String get label => switch (this) {
        ApplicationStatus.pending => 'Pending',
        ApplicationStatus.accepted => 'Accepted',
        ApplicationStatus.rejected => 'Refused',
      };
}

/// A student's application to an offer.
///
/// The student's list (GET /jobs/applications/mine) fills the offer fields
/// ([jobTitle], [company], [location]); the company's list
/// (GET /jobs/:id/applications) fills the applicant fields.
class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.status,
    required this.appliedAt,
    this.decidedAt,
    this.jobTitle = '',
    this.company = '',
    this.location = '',
    this.applicantName = '',
    this.applicantEmail = '',
  });

  final String id;
  final String jobId;
  final ApplicationStatus status;
  final DateTime appliedAt;
  final DateTime? decidedAt;

  final String jobTitle;
  final String company;
  final String location;

  final String applicantName;
  final String applicantEmail;

  bool get isPending => status == ApplicationStatus.pending;

  /// "Company · Location", or just the company when there is no location.
  String get companyLine => location.isEmpty ? company : '$company · $location';

  /// "05/11/2026".
  String get appliedOn => formatApplicationDate(appliedAt);

  JobApplication withStatus(ApplicationStatus status) => JobApplication(
        id: id,
        jobId: jobId,
        status: status,
        appliedAt: appliedAt,
        decidedAt: status == ApplicationStatus.pending ? null : DateTime.now(),
        jobTitle: jobTitle,
        company: company,
        location: location,
        applicantName: applicantName,
        applicantEmail: applicantEmail,
      );
}

String formatApplicationDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
