import 'entities/lost_item.dart';
import 'entities/lost_item_match.dart';

/// "Correspondances possibles" by rules, as the API scores them without AI
/// (backend/src/modules/forum/lost-item-matching.ts). Used by the mock.
///
/// Score (0-100): +40 same category (+20 when both are "Autre"); +25 the
/// same day, down to 0 at 14 days apart (more than 30 days apart: never a
/// match); +20 x shared place words (zone + location), at least +10 for the
/// same kind of place; +15 x shared words of the title + distinctive detail.
/// Matches under 50 are dropped, the 5 best kept.
LostItemMatches matchLostItemsByRules(LostItem source, Iterable<LostItem> board) {
  if (source.isResolved) return const LostItemMatches(items: []);
  final matches = <LostItemMatch>[];
  for (final candidate in board) {
    if (candidate.id == source.id ||
        candidate.kind == source.kind ||
        candidate.isResolved) {
      continue;
    }
    final match = lostItemRuleMatch(source, candidate);
    if (match != null && match.score >= 50) matches.add(match);
  }
  matches.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : b.item.reportedAt.compareTo(a.item.reportedAt);
  });
  return LostItemMatches(items: matches.take(5).toList());
}

/// How much [candidate] looks like [source], or null when they are more than
/// 30 days apart.
LostItemMatch? lostItemRuleMatch(LostItem source, LostItem candidate) {
  final days =
      source.reportedAt.difference(candidate.reportedAt).inMinutes.abs() / (24 * 60);
  if (days > 30) return null;

  var score = 0;
  final reasons = <String>[];

  if (source.category == candidate.category) {
    score += source.category == LostItemCategory.other ? 20 : 40;
    reasons.add('Même catégorie');
  }
  if (days <= 14) {
    final points = (25 * (1 - days / 14)).round();
    if (points > 0) {
      score += points;
      final apart = days.round();
      reasons.add(days < 1
          ? 'Même jour'
          : apart == 1
              ? "1 jour d'écart"
              : "$apart jours d'écart");
    }
  }

  final samePlaceKind =
      source.place == candidate.place && source.place != LostItemPlace.other;
  var place = _overlap(_placeWords(source), _placeWords(candidate));
  if (samePlaceKind && place < 0.5) place = 0.5;
  final placePoints = (20 * place).round();
  if (placePoints > 0) {
    score += placePoints;
    reasons.add('Lieu proche');
  }

  final textPoints = (15 * _overlap(_textWords(source), _textWords(candidate))).round();
  if (textPoints > 0) {
    score += textPoints;
    reasons.add('Description proche');
  }

  return LostItemMatch(
    item: candidate,
    score: score > 100 ? 100 : score,
    reason: reasons.join(' · '),
    reasons: reasons,
  );
}

const _stopWords = {
  'les', 'des', 'une', 'pour', 'avec', 'sur', 'dans', 'par', 'the', 'and', 'with', 'for', //
  'esprit',
};

/// Words longer than 2 letters, lowercase, without French accents.
Set<String> lostItemWords(String text) => foldForSearch(text)
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((word) => word.length > 2 && !_stopWords.contains(word))
    .toSet();

Set<String> _placeWords(LostItem item) => lostItemWords('${item.zone} ${item.location}');

Set<String> _textWords(LostItem item) =>
    lostItemWords('${item.title} ${item.distinctiveDetail ?? ''}');

double _overlap(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final shared = a.where(b.contains).length;
  return shared / (a.length < b.length ? a.length : b.length);
}
