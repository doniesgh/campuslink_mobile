import { model, Schema, type InferSchemaType } from 'mongoose';

/** The actions recorded so far. Named `<thing>.<verb>` so they can be filtered by prefix. */
export const AUDIT_ACTIONS = ['user.create', 'user.update', 'user.delete', 'user.import'] as const;
export type AuditAction = (typeof AUDIT_ACTIONS)[number];

/** Who did it, copied when it happened: it survives the actor's deletion or renaming. */
const actorSchema = new Schema(
  {
    id: { type: String, required: true },
    displayName: { type: String, required: true },
    email: { type: String, required: true },
  },
  { _id: false },
);

/** One change an admin made. Entries are never edited or deleted by the API. */
const auditLogSchema = new Schema(
  {
    action: { type: String, required: true },
    /** One sentence for people: "Changed the role of Sarra Mansouri to Teacher". */
    summary: { type: String, required: true },
    actor: { type: actorSchema, required: true },
    /** The account acted on, if any (kept as a string: it may have been deleted since). */
    targetId: { type: String, default: null },
    /** Details for the screen (never a password). */
    metadata: { type: Schema.Types.Mixed, default: () => ({}) },
    ip: { type: String, default: null },
  },
  { timestamps: { createdAt: true, updatedAt: false }, minimize: false },
);

auditLogSchema.index({ createdAt: -1, _id: -1 });
auditLogSchema.index({ action: 1, createdAt: -1 });

export type AuditLog = InferSchemaType<typeof auditLogSchema>;

export const AuditLogModel = model('AuditLog', auditLogSchema);
