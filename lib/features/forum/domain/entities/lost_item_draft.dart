import 'lost_item.dart';

/// What a student fills in to publish a Lost & Found notice. The server adds
/// the reporter, the date and the "LF-412" reference.
///
/// [reward] and [isUrgent] are for lost items, [dropOffNote] and
/// [pickupDesk] for found items: the other kind's fields are not sent.
class LostItemDraft {
  const LostItemDraft({
    required this.kind,
    required this.title,
    required this.category,
    required this.zone,
    required this.location,
    required this.place,
    this.distinctiveDetail,
    this.reward,
    this.isUrgent = false,
    this.dropOffNote,
    this.pickupDesk,
  });

  final LostItemKind kind;
  final String title;
  final LostItemCategory category;

  /// Short area: "Bloc C", "Parking".
  final String zone;

  /// Full location: "Salle C12 (Ghazela)".
  final String location;
  final LostItemPlace place;
  final String? distinctiveDetail;
  final String? reward;
  final bool isUrgent;
  final String? dropOffNote;
  final String? pickupDesk;

  bool get isLost => kind == LostItemKind.lost;
}
