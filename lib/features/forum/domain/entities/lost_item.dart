/// Whether an item was reported missing by its owner or handed in by a finder.
enum LostItemKind { lost, found }

/// What the item looks like (drives the thumbnail icon).
enum LostItemCategory { calculator, keys, audio, bag, card, bottle, other }

/// Kind of place where the item was lost or found (drives the location icon).
enum LostItemPlace { classroom, parking, library, cafeteria, other }

/// `active`: listed and matched. `resolved`: back with its owner (still
/// listed, without its action, and never matched).
enum LostItemStatus { active, resolved }

/// What a student can do with an item from the list.
enum LostItemAction {
  /// Found item: "C'est à moi / Réclamer".
  claim,

  /// Lost item: "J'ai trouvé cet objet !".
  reportFound,

  /// Found item whose serial number is hidden: the owner proves it's theirs.
  verifySerial,
}

/// A post of the forum "Lost & Found" section.
class LostItem {
  const LostItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.zone,
    required this.location,
    required this.place,
    required this.reporterName,
    required this.reportedAt,
    this.reference,
    this.reporterIsStaff = false,
    this.photoCount = 0,
    this.isUrgent = false,
    this.reward,
    this.distinctiveDetail,
    this.dropOffNote,
    this.pickupDesk,
    this.isSerialHidden = false,
    this.status = LostItemStatus.active,
    this.isMine = false,
    this.canManage = false,
  });

  final String id;
  final LostItemKind kind;
  final String title;
  final LostItemCategory category;

  /// Short area shown in the status pill: "Bloc C", "Parking", "Bibliothèque".
  final String zone;

  /// Full location: "Salle C12 (Ghazela)".
  final String location;
  final LostItemPlace place;

  /// Who handed the item in (found) or reported it missing (lost).
  final String reporterName;
  final bool reporterIsStaff;
  final DateTime reportedAt;

  /// Handover reference given by the desk, e.g. "TF-409".
  final String? reference;
  final int photoCount;
  final bool isUrgent;

  /// Reward offered by the owner of a lost item ("Café offert ☕").
  final String? reward;

  /// Detail that helps recognise a lost item ("Boîtier 3 boutons noir").
  final String? distinctiveDetail;

  /// Where the finder left a found item ("Déposé à l'accueil Bloc C").
  final String? dropOffNote;

  /// Desk where the owner collects a found item ("Accueil Bloc C").
  final String? pickupDesk;

  /// The serial number is hidden so the owner can prove ownership.
  final bool isSerialHidden;

  final LostItemStatus status;

  /// The signed-in student reported it.
  final bool isMine;

  /// The signed-in user may edit, resolve or delete it (its reporter, or an admin).
  final bool canManage;

  bool get isLost => kind == LostItemKind.lost;

  bool get isResolved => status == LostItemStatus.resolved;

  /// The same item with another [status].
  LostItem withStatus(LostItemStatus status) => LostItem(
        id: id,
        kind: kind,
        title: title,
        category: category,
        zone: zone,
        location: location,
        place: place,
        reporterName: reporterName,
        reportedAt: reportedAt,
        reference: reference,
        reporterIsStaff: reporterIsStaff,
        photoCount: photoCount,
        isUrgent: isUrgent,
        reward: reward,
        distinctiveDetail: distinctiveDetail,
        dropOffNote: dropOffNote,
        pickupDesk: pickupDesk,
        isSerialHidden: isSerialHidden,
        status: status,
        isMine: isMine,
        canManage: canManage,
      );

  LostItemAction get action => isLost
      ? LostItemAction.reportFound
      : isSerialHidden
          ? LostItemAction.verifySerial
          : LostItemAction.claim;

  /// Case- and accent-insensitive search on the title, location, zone and reference.
  bool matches(String query) {
    final q = foldForSearch(query.trim());
    if (q.isEmpty) return true;
    return [title, location, zone, reference ?? '']
        .any((field) => foldForSearch(field).contains(q));
  }
}

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ç': 'c', 'ÿ': 'y',
};

/// Lowercases [text] and strips French accents ("Écouteurs" -> "ecouteurs").
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString();
}

/// Items of [kind] (all kinds when null) that match [query], in their original order.
List<LostItem> filterLostItems(
  List<LostItem> items, {
  LostItemKind? kind,
  String query = '',
}) =>
    items
        .where((item) => (kind == null || item.kind == kind) && item.matches(query))
        .toList();

/// Number of items per filter pill ("Tous", "Objets Perdus", "Objets Trouvés").
typedef LostItemCounts = ({int all, int lost, int found});

LostItemCounts countLostItems(List<LostItem> items) {
  final lost = items.where((item) => item.isLost).length;
  return (all: items.length, lost: lost, found: items.length - lost);
}
