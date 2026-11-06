/// "Aucun commentaire" / "1 commentaire" / "8 commentaires".
String ideaCommentsLabel(int count) => switch (count) {
      <= 0 => 'Aucun commentaire',
      1 => '1 commentaire',
      _ => '$count commentaires',
    };

/// "1 idée" / "12 idées".
String ideaCountLabel(int count) => count == 1 ? '1 idée' : '$count idées';

/// Spoken label of the upvote button.
String ideaUpvoteSemantics(int upvotes, {required bool isUpvotedByMe}) {
  final votes = upvotes == 1 ? '1 vote' : '$upvotes votes';
  return isUpvotedByMe ? 'Retirer mon vote, $votes' : 'Voter pour cette idée, $votes';
}
