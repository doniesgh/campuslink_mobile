import '../../domain/entities/forum_post.dart';
import '../../domain/entities/lost_item.dart';

/// Expected backend post JSON (one entry of GET /forum/highlights):
/// { "id": "post-1", "authorName": "Sarra K.", "authorInfo": "5A - Informatique",
///   "category": "carpool", "tag": "2 places", "body": "...", "place": "Passage → Ghazela",
///   "upvotes": 0, "comments": 0, "status": null, "postedAt": "2026-11-06T12:48:00.000Z" }
class ForumPostModel extends ForumPost {
  const ForumPostModel({
    required super.id,
    required super.authorName,
    required super.authorInfo,
    required super.category,
    required super.body,
    required super.postedAt,
    required super.tag,
    super.place,
    super.upvotes,
    super.comments,
    super.status,
  });

  factory ForumPostModel.fromJson(Map<String, dynamic> json) => ForumPostModel(
        id: json['id'] as String,
        authorName: json['authorName'] as String,
        authorInfo: json['authorInfo'] as String,
        category: _enumByName(PostCategory.values, json['category']),
        body: json['body'] as String,
        postedAt: _instant(json['postedAt']),
        tag: json['tag'] as String,
        place: json['place'] as String?,
        upvotes: _int(json['upvotes']),
        comments: _int(json['comments']),
        status: json['status'] as String?,
      );
}

/// Expected backend item JSON (one entry of GET /forum/lost-items):
/// { "id": "lf-409", "kind": "found", "title": "...", "category": "calculator",
///   "zone": "Bloc C", "location": "Salle C12 (Ghazela)", "place": "classroom",
///   "reporterName": "Youssef M.", "reporterIsStaff": false,
///   "reportedAt": "2026-11-06T12:15:00.000Z", "reference": "TF-409", "photoCount": 1,
///   "isUrgent": false, "reward": null, "distinctiveDetail": null,
///   "dropOffNote": "...", "pickupDesk": "...", "isSerialHidden": false }
class LostItemModel extends LostItem {
  const LostItemModel({
    required super.id,
    required super.kind,
    required super.title,
    required super.category,
    required super.zone,
    required super.location,
    required super.place,
    required super.reporterName,
    required super.reportedAt,
    super.reference,
    super.reporterIsStaff,
    super.photoCount,
    super.isUrgent,
    super.reward,
    super.distinctiveDetail,
    super.dropOffNote,
    super.pickupDesk,
    super.isSerialHidden,
  });

  factory LostItemModel.fromJson(Map<String, dynamic> json) => LostItemModel(
        id: json['id'] as String,
        kind: _enumByName(LostItemKind.values, json['kind']),
        title: json['title'] as String,
        // Unknown categories and places (added later by the API) show the generic icon.
        category: _enumByName(
          LostItemCategory.values,
          json['category'],
          fallback: LostItemCategory.other,
        ),
        zone: json['zone'] as String,
        location: json['location'] as String,
        place: _enumByName(LostItemPlace.values, json['place'], fallback: LostItemPlace.other),
        reporterName: json['reporterName'] as String,
        reporterIsStaff: (json['reporterIsStaff'] as bool?) ?? false,
        reportedAt: _instant(json['reportedAt']),
        reference: json['reference'] as String?,
        photoCount: _int(json['photoCount']),
        isUrgent: (json['isUrgent'] as bool?) ?? false,
        reward: json['reward'] as String?,
        distinctiveDetail: json['distinctiveDetail'] as String?,
        dropOffNote: json['dropOffNote'] as String?,
        pickupDesk: json['pickupDesk'] as String?,
        isSerialHidden: (json['isSerialHidden'] as bool?) ?? false,
      );
}

/// The API sends enums as the Dart value names ("lostFound").
T _enumByName<T extends Enum>(List<T> values, Object? name, {T? fallback}) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  if (fallback != null) return fallback;
  throw FormatException('Unknown ${T.toString()} value: $name');
}

/// ISO-8601 UTC instant, shown in the phone's time zone.
DateTime _instant(Object? value) => DateTime.parse(value as String).toLocal();

int _int(Object? value) => (value as num?)?.toInt() ?? 0;
