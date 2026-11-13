import { model, Schema, Types, type InferSchemaType } from 'mongoose';

// Enum values are the app's Dart enum names (LostItemKind, LostItemCategory, LostItemPlace).
export const LOST_ITEM_KINDS = ['lost', 'found'] as const;
export const LOST_ITEM_CATEGORIES = [
  'calculator',
  'keys',
  'audio',
  'bag',
  'card',
  'bottle',
  'other',
] as const;
export const LOST_ITEM_PLACES = ['classroom', 'parking', 'library', 'cafeteria', 'other'] as const;

/** `active`: listed and matched · `resolved`: the item went back to its owner (still listed, never matched). */
export const LOST_ITEM_STATUSES = ['active', 'resolved'] as const;
export type LostItemStatus = (typeof LOST_ITEM_STATUSES)[number];

/**
 * A post of the Lost & Found board: an item reported missing by its owner
 * (`lost`) or handed in by a finder (`found`). The reporter is shown as a
 * name; notices published from the app also keep the reporter's account id
 * (most demo items have none: only an admin can manage them). Ids are
 * strings so the demo items keep the app's ids ("lf-409").
 */
const lostItemSchema = new Schema(
  {
    _id: { type: String, default: () => new Types.ObjectId().toHexString() },
    kind: { type: String, enum: LOST_ITEM_KINDS, required: true },
    title: { type: String, required: true, trim: true },
    category: { type: String, enum: LOST_ITEM_CATEGORIES, required: true },

    /** Short area shown in the status pill: "Bloc C", "Parking". */
    zone: { type: String, required: true },

    /** Full location: "Salle C12 (Ghazela)". */
    location: { type: String, required: true },
    place: { type: String, enum: LOST_ITEM_PLACES, required: true },
    reporterId: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    reporterName: { type: String, required: true },
    reporterIsStaff: { type: Boolean, default: false },
    reportedAt: { type: Date, required: true },

    /** Handover reference: given by the desk ("TF-409"), or generated on publish ("LF-412"). */
    reference: { type: String, default: null },
    photoCount: { type: Number, default: 0, min: 0 },
    isUrgent: { type: Boolean, default: false },
    reward: { type: String, default: null },
    distinctiveDetail: { type: String, default: null },
    dropOffNote: { type: String, default: null },
    pickupDesk: { type: String, default: null },

    /** The serial number is hidden so the owner can prove ownership. */
    isSerialHidden: { type: Boolean, default: false },

    /** Items saved before statuses existed have none: they are active. */
    status: { type: String, enum: LOST_ITEM_STATUSES, default: 'active' },
  },
  { timestamps: true },
);

lostItemSchema.index({ reportedAt: -1 });

export type LostItem = InferSchemaType<typeof lostItemSchema>;

export const LostItemModel = model('LostItem', lostItemSchema);

/** What the API sends for an item (the shape the app's LostItemModel.fromJson reads). */
export interface PublicLostItem {
  id: string;
  kind: (typeof LOST_ITEM_KINDS)[number];
  title: string;
  category: (typeof LOST_ITEM_CATEGORIES)[number];
  zone: string;
  location: string;
  place: (typeof LOST_ITEM_PLACES)[number];
  reporterName: string;
  reporterIsStaff: boolean;
  reportedAt: string;
  reference: string | null;
  photoCount: number;
  isUrgent: boolean;
  reward: string | null;
  distinctiveDetail: string | null;
  dropOffNote: string | null;
  pickupDesk: string | null;
  isSerialHidden: boolean;
  status: LostItemStatus;
  /** The reporter's account id, or null (demo items, desk notices). */
  reporterId: string | null;
  /** The viewer reported it. */
  isMine: boolean;
  /** The viewer may edit, resolve or delete it: the reporter, or an admin. */
  canManage: boolean;
}

/** Who is looking at an item: decides `isMine` and `canManage`. */
export interface LostItemViewer {
  userId: string;
  isAdmin: boolean;
}

/** The reporter's account id as a string, or null. */
export const reporterIdOf = (item: Pick<LostItem, 'reporterId'>): string | null =>
  item.reporterId ? String(item.reporterId) : null;

/** [item] in the API shape, as [viewer] sees it (no viewer: nobody's, nobody can manage it). */
export function toPublicLostItem(item: LostItem, viewer?: LostItemViewer): PublicLostItem {
  const reporterId = reporterIdOf(item);
  const isMine = viewer !== undefined && reporterId !== null && reporterId === viewer.userId;
  return {
    id: item._id,
    kind: item.kind,
    title: item.title,
    category: item.category,
    zone: item.zone,
    location: item.location,
    place: item.place,
    reporterName: item.reporterName,
    reporterIsStaff: item.reporterIsStaff,
    reportedAt: item.reportedAt.toISOString(),
    reference: item.reference ?? null,
    photoCount: item.photoCount,
    isUrgent: item.isUrgent,
    reward: item.reward ?? null,
    distinctiveDetail: item.distinctiveDetail ?? null,
    dropOffNote: item.dropOffNote ?? null,
    pickupDesk: item.pickupDesk ?? null,
    isSerialHidden: item.isSerialHidden,
    status: item.status ?? 'active',
    reporterId,
    isMine,
    canManage: isMine || viewer?.isAdmin === true,
  };
}
