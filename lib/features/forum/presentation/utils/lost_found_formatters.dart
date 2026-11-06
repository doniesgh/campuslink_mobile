import '../../domain/entities/lost_item.dart';

/// "À l'instant" / "Il y a 45 min" / "Aujourd'hui, 11h" / "Hier, 16h30" / "05/11"
/// (French, as in the Lost & Found mockup).
String formatLostItemTime(DateTime d, {required DateTime now}) {
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';

  // UTC dates so a daylight-saving change does not shorten a day.
  final days = DateTime.utc(now.year, now.month, now.day)
      .difference(DateTime.utc(d.year, d.month, d.day))
      .inDays;
  final time = d.minute == 0
      ? '${d.hour}h'
      : '${d.hour}h${d.minute.toString().padLeft(2, '0')}';
  if (days == 0) return "Aujourd'hui, $time";
  if (days == 1) return 'Hier, $time';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Status pill text: "Trouvé · Bloc C" / "Perdu · Parking".
String lostItemStatusLabel(LostItem item) =>
    '${item.isLost ? 'Perdu' : 'Trouvé'} · ${item.zone}';

/// "Déposé par" (found) / "Signalé par" (lost).
String lostItemReporterPrefix(LostItem item) =>
    item.isLost ? 'Signalé par' : 'Déposé par';

/// Category chip of the "Publier une annonce" form.
String lostItemCategoryLabel(LostItemCategory category) => switch (category) {
      LostItemCategory.calculator => 'Calculatrice',
      LostItemCategory.keys => 'Clés',
      LostItemCategory.audio => 'Audio',
      LostItemCategory.bag => 'Sac',
      LostItemCategory.card => 'Carte',
      LostItemCategory.bottle => 'Gourde',
      LostItemCategory.other => 'Autre',
    };

/// Place chip of the "Publier une annonce" form.
String lostItemPlaceLabel(LostItemPlace place) => switch (place) {
      LostItemPlace.classroom => 'Salle de cours',
      LostItemPlace.parking => 'Parking',
      LostItemPlace.library => 'Bibliothèque',
      LostItemPlace.cafeteria => 'Cafétéria',
      LostItemPlace.other => 'Autre',
    };
