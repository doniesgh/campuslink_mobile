import { model, Schema, type InferSchemaType } from 'mongoose';

/**
 * The actions recorded. Named `<thing>.<verb>` so they can be filtered by
 * prefix (`user.*`). The app shows a label for each (audit_log_page.dart).
 * - `user.*`: an admin managed accounts (`user.import.assist`: asked the AI
 *   how an import file is laid out).
 * - `auth.*`: a user changed their own password (with the emailed code, or
 *   signed in): the actor is that user.
 */
export const AUDIT_ACTIONS = [
  'user.create',
  'user.update',
  'user.delete',
  'user.import',
  'user.import.assist',
  'auth.password_reset',
  'auth.password_change',
  // An admin added, changed or removed a class of the weekly timetable.
  'timetable.slot.create',
  'timetable.slot.update',
  'timetable.slot.delete',
] as const;
export type AuditAction = (typeof AUDIT_ACTIONS)[number];

/** What an entry is about (`targetType`), when it is about one thing. */
export const AUDIT_TARGET_TYPES = ['user'] as const;
export type AuditTargetType = (typeof AUDIT_TARGET_TYPES)[number];

/** Who did it, copied when it happened: it survives the actor's deletion or renaming. */
const actorSchema = new Schema(
  {
    id: { type: String, required: true },
    displayName: { type: String, required: true },
    email: { type: String, required: true },
  },
  { _id: false },
);

/** One change an admin (or a user, on their own account) made. Entries are never edited or deleted by the API. */
const auditLogSchema = new Schema(
  {
    action: { type: String, required: true },
    /** One sentence for people: "Changed the role of Sarra Mansouri to Teacher". */
    summary: { type: String, required: true },
    actor: { type: actorSchema, required: true },
    /** What [targetId] is (`user`), or null for an entry about no one thing (an import). */
    targetType: { type: String, default: null },
    /** The account acted on, if any (kept as a string: it may have been deleted since). */
    targetId: { type: String, default: null },
    /** Details for the screen (never a password). */
    metadata: { type: Schema.Types.Mixed, default: () => ({}) },
    ip: { type: String, default: null },
    /** The User-Agent of the request (at most 512 characters). */
    userAgent: { type: String, default: null },
  },
  { timestamps: { createdAt: true, updatedAt: false }, minimize: false },
);

auditLogSchema.index({ createdAt: -1, _id: -1 });
auditLogSchema.index({ action: 1, createdAt: -1 });

export type AuditLog = InferSchemaType<typeof auditLogSchema>;

export const AuditLogModel = model('AuditLog', auditLogSchema);
