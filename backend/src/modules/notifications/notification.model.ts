import { Types, model, Schema, type InferSchemaType } from 'mongoose';

// Enum values are the names of the app's Dart enums (app_notification.dart).
export const notificationCategories = [
  'academic',
  'covoiturage',
  'lostFound',
  'career',
  'community',
  'account',
] as const;

export const notificationDestinations = [
  'home',
  'timetable',
  'courses',
  'grades',
  'forum',
  'ride',
  'job',
  'profile',
  'adminUsers',
] as const;

export const attachmentTypes = ['place', 'ride', 'schedule', 'pickup'] as const;

export type NotificationCategory = (typeof notificationCategories)[number];
export type NotificationDestination = (typeof notificationDestinations)[number];

/** Extra block under the body. Only the fields of its `type` are set. */
const attachmentSchema = new Schema(
  {
    type: { type: String, enum: attachmentTypes, required: true },
    place: String, // place
    driverName: String, // ride
    carLabel: String, // ride
    isDriverVerified: Boolean, // ride
    availability: String, // pickup
    ticket: String, // pickup
  },
  { _id: false },
);

/** Screen the notification opens. `id` is the ride, job or user id for detail screens. */
const linkSchema = new Schema(
  {
    destination: { type: String, enum: notificationDestinations, required: true },
    id: { type: String, default: null },
  },
  { _id: false },
);

/** One notification of one student. */
const notificationSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },

    /**
     * The id the API sends. Readable for demo and system notifications
     * ('room-change-gl', 'welcome'), random otherwise. Unique per student.
     */
    key: { type: String, required: true, default: () => new Types.ObjectId().toHexString() },

    category: { type: String, enum: notificationCategories, required: true },
    /** Badge text: "Urgent Academic", "Covoiturage"... */
    label: { type: String, required: true },
    title: { type: String, required: true },
    /** Light markup the app renders: **strong**, ~~struck~~, ==highlight==. */
    body: { type: String, required: true },
    receivedAt: { type: Date, required: true, default: Date.now },
    isRead: { type: Boolean, default: false },
    isUrgent: { type: Boolean, default: false },
    attachment: { type: attachmentSchema, default: null },
    link: { type: linkSchema, default: null },
  },
  { timestamps: true },
);

notificationSchema.index({ userId: 1, key: 1 }, { unique: true });
notificationSchema.index({ userId: 1, receivedAt: -1 });

export type Notification = InferSchemaType<typeof notificationSchema>;

export const NotificationModel = model('Notification', notificationSchema);

/** What the API sends (the shape the app's AppNotificationModel.fromJson reads). */
export type NotificationAttachmentJson =
  | { type: 'place'; place: string }
  | { type: 'ride'; driverName: string; carLabel: string; isDriverVerified: boolean }
  | { type: 'schedule' }
  | { type: 'pickup'; availability: string; ticket: string };

export interface NotificationLinkJson {
  destination: NotificationDestination;
  id: string | null;
}

export interface NotificationJson {
  id: string;
  category: NotificationCategory;
  label: string;
  title: string;
  body: string;
  receivedAt: string;
  isRead: boolean;
  isUrgent: boolean;
  attachment: NotificationAttachmentJson | null;
  link: NotificationLinkJson | null;
}

type StoredAttachment = NonNullable<Notification['attachment']>;

function toAttachmentJson(a: StoredAttachment | null | undefined): NotificationAttachmentJson | null {
  if (!a) return null;
  switch (a.type) {
    case 'place':
      return { type: 'place', place: a.place ?? '' };
    case 'ride':
      return {
        type: 'ride',
        driverName: a.driverName ?? '',
        carLabel: a.carLabel ?? '',
        isDriverVerified: a.isDriverVerified ?? false,
      };
    case 'schedule':
      return { type: 'schedule' };
    case 'pickup':
      return { type: 'pickup', availability: a.availability ?? '', ticket: a.ticket ?? '' };
    default:
      return null;
  }
}

export const toNotificationJson = (n: Notification): NotificationJson => ({
  id: n.key,
  category: n.category as NotificationCategory,
  label: n.label,
  title: n.title,
  body: n.body,
  receivedAt: n.receivedAt.toISOString(),
  isRead: n.isRead ?? false,
  isUrgent: n.isUrgent ?? false,
  attachment: toAttachmentJson(n.attachment),
  link: n.link
    ? { destination: n.link.destination as NotificationDestination, id: n.link.id ?? null }
    : null,
});
