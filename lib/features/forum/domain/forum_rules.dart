import 'entities/lost_item_draft.dart';

// Publishing rules of the forum: the same limits and French messages as the
// API (backend/src/modules/forum/forum.schemas.ts). The forms check them
// before sending, and MockForumRepository applies them.

abstract final class LostItemLimits {
  static const title = 80;
  static const zone = 40;
  static const location = 120;
  static const distinctiveDetail = 200;
  static const reward = 60;
  static const dropOffNote = 120;
  static const pickupDesk = 120;
}

abstract final class IdeaLimits {
  static const bodyMin = 10;
  static const bodyMax = 500;
  static const tag = 24;
}

/// Badge of an idea published without a theme.
const defaultIdeaTag = 'Proposition';

String? _required(String? text, String missing, int max, String tooLong) {
  final value = text?.trim() ?? '';
  if (value.isEmpty) return missing;
  return value.length > max ? tooLong : null;
}

String? _optional(String? text, int max, String tooLong) =>
    (text?.trim().length ?? 0) > max ? tooLong : null;

String? lostItemTitleError(String? text) => _required(
      text,
      "Donnez un titre à l'annonce (ex : Calculatrice TI-84).",
      LostItemLimits.title,
      'Le titre ne doit pas dépasser ${LostItemLimits.title} caractères.',
    );

String? lostItemZoneError(String? text) => _required(
      text,
      'Indiquez la zone (ex : Bloc C).',
      LostItemLimits.zone,
      'La zone ne doit pas dépasser ${LostItemLimits.zone} caractères.',
    );

String? lostItemLocationError(String? text) => _required(
      text,
      'Précisez le lieu (ex : Salle C12).',
      LostItemLimits.location,
      'Le lieu ne doit pas dépasser ${LostItemLimits.location} caractères.',
    );

String? lostItemDetailError(String? text) => _optional(
      text,
      LostItemLimits.distinctiveDetail,
      'Le détail distinctif ne doit pas dépasser ${LostItemLimits.distinctiveDetail} caractères.',
    );

String? lostItemRewardError(String? text) => _optional(
      text,
      LostItemLimits.reward,
      'La récompense ne doit pas dépasser ${LostItemLimits.reward} caractères.',
    );

/// Where a found item was left: required for found items.
String? lostItemPickupDeskError(String? text) => _required(
      text,
      "Indiquez où l'objet a été déposé (ex : Accueil Bloc C).",
      LostItemLimits.pickupDesk,
      'Le lieu de retrait ne doit pas dépasser ${LostItemLimits.pickupDesk} caractères.',
    );

/// The first problem of [draft] (in the order of the form), or null.
String? lostItemDraftError(LostItemDraft draft) {
  final common = lostItemTitleError(draft.title) ??
      lostItemZoneError(draft.zone) ??
      lostItemLocationError(draft.location) ??
      lostItemDetailError(draft.distinctiveDetail);
  if (common != null) return common;
  if (draft.isLost) return lostItemRewardError(draft.reward);

  final note = draft.dropOffNote?.trim() ?? '';
  final desk = draft.pickupDesk?.trim() ?? '';
  if (note.isEmpty && desk.isEmpty) return lostItemPickupDeskError(null);
  return _optional(
        note,
        LostItemLimits.dropOffNote,
        'La note de dépôt ne doit pas dépasser ${LostItemLimits.dropOffNote} caractères.',
      ) ??
      (desk.isEmpty ? null : lostItemPickupDeskError(desk));
}

String? ideaBodyError(String? text) {
  final body = text?.trim() ?? '';
  if (body.isEmpty) return 'Décrivez votre idée.';
  if (body.length < IdeaLimits.bodyMin) {
    return 'Votre idée est trop courte : ${IdeaLimits.bodyMin} caractères minimum.';
  }
  if (body.length > IdeaLimits.bodyMax) {
    return 'Votre idée ne doit pas dépasser ${IdeaLimits.bodyMax} caractères.';
  }
  return null;
}

String? ideaTagError(String? text) => _optional(
      text,
      IdeaLimits.tag,
      'Le thème ne doit pas dépasser ${IdeaLimits.tag} caractères.',
    );
