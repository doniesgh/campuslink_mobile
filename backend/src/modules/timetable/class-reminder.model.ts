import { model, Schema } from 'mongoose';

/** How long a sent reminder is remembered (then MongoDB deletes it). */
const KEEP_SECONDS = 2 * 24 * 60 * 60;

/**
 * One class reminder that went out: `key` is the session id of the
 * timetable ('algo-cm-2026-11-9'). The unique index makes each reminder go
 * out once, even with several API instances running the job.
 */
const classReminderSchema = new Schema({
  key: { type: String, required: true, unique: true },
  sentAt: { type: Date, required: true, default: Date.now, expires: KEEP_SECONDS },
});

export const ClassReminderModel = model('ClassReminder', classReminderSchema);
