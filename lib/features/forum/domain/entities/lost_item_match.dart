import 'lost_item.dart';

/// A notice that may be the same object as the one the student looks at.
class LostItemMatch {
  const LostItemMatch({
    required this.item,
    required this.score,
    required this.reason,
    this.reasons = const [],
    this.ai = false,
  });

  final LostItem item;

  /// How likely it is the same object, 0-100.
  final int score;

  /// Why: the AI's sentence, or the rule reasons ("Même catégorie · Même jour").
  final String reason;

  /// The rule reasons, one per rule that matched.
  final List<String> reasons;

  /// The AI scored this match.
  final bool ai;
}

/// The "Correspondances possibles" of a notice, best first.
class LostItemMatches {
  const LostItemMatches({required this.items, this.ai = false, this.model});

  final List<LostItemMatch> items;

  /// The AI re-ranked them (false: rules only).
  final bool ai;

  /// The AI model that answered, or null.
  final String? model;
}
