/// The AI summary of an offer (POST /jobs/:id/summary), in the user's language.
class JobSummary {
  const JobSummary({
    required this.summary,
    this.keyPoints = const [],
    this.skills = const [],
    this.idealFor = '',
    this.model = '',
    this.cached = false,
  });

  /// 2 or 3 sentences.
  final String summary;

  /// 3 to 5 short bullet points.
  final List<String> keyPoints;

  /// The skills and technologies the offer asks for.
  final List<String> skills;

  /// One sentence on the student it suits best ('' when the AI didn't say).
  final String idealFor;

  /// The AI model that wrote it.
  final String model;

  /// Served from the server's cache (no new AI call).
  final bool cached;
}
