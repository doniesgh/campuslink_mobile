import { z } from 'zod';

import { SESSION_KINDS, SESSION_MODES } from './timetable.model';

/**
 * Limits of a class of the weekly timetable. The app checks the same rules,
 * with the same messages, before sending:
 * lib/features/timetable/domain/timetable_slot_rules.dart. Change both together.
 */
export const SLOT_LIMITS = {
  courseMaxLength: 120,
  roomMaxLength: 60,
  teacherMaxLength: 80,
  notesMaxLength: 1000,
  meetUrlMaxLength: 200,
  /** A class lasts at most 8 hours (as in the PWA). */
  maxDurationMinutes: 8 * 60,
  maxCoefficient: 10,
} as const;

const L = SLOT_LIMITS;

/** A Google Meet link: https://meet.google.com/abc-defg-hij (same rule as the PWA). */
export const MEET_URL_PATTERN =
  /^https:\/\/meet\.google\.com\/[a-z0-9_-]{3,40}(?:\/[a-z0-9_-]+)?(?:\?\S*)?$/i;

// The admin screens are in English, so these messages are too.
export const SLOT_MESSAGES = {
  weekday: 'Choose a day from Monday to Sunday',
  start: 'Enter the start time as HH:mm',
  end: 'Enter the end time as HH:mm',
  endBeforeStart: 'The class must end after it starts',
  tooLong: 'A class lasts at most 8 hours',
  courseMissing: 'Enter the course',
  courseTooLong: `The course name is too long (${L.courseMaxLength} characters max)`,
  roomMissing: 'Enter the room of an on-site class',
  roomTooLong: `The room is too long (${L.roomMaxLength} characters max)`,
  teacherMissing: 'Enter the teacher',
  teacherTooLong: `The teacher's name is too long (${L.teacherMaxLength} characters max)`,
  kind: 'Kind: choose lecture, lab, exam or workshop',
  mode: 'Mode: choose onsite or online',
  meetUrlMissing: 'Enter the Google Meet link of an online class',
  meetUrlInvalid: 'Enter a Google Meet link, like https://meet.google.com/abc-defg-hij',
  notesTooLong: `The notes are too long (${L.notesMaxLength} characters max)`,
  coefficient: `The coefficient must be between 0 and ${L.maxCoefficient}`,
  nothingToUpdate: 'Nothing to update',
} as const;

const M = SLOT_MESSAGES;

/** A trimmed, non-blank string of at most [max] characters. */
const text = (missing: string, max: number, tooLong: string) =>
  z.string({ error: missing }).trim().min(1, missing).max(max, tooLong);

/** Wall-clock 'HH:mm', 00:00 to 23:59. */
const hm = (message: string) =>
  z.string({ error: message }).regex(/^([01]\d|2[0-3]):[0-5]\d$/, message);

/** Every field of a class, each with its own rules (the rules between fields are in [checkSlot]). */
const fields = {
  weekday: z.number({ error: M.weekday }).int(M.weekday).min(1, M.weekday).max(7, M.weekday),
  start: hm(M.start),
  end: hm(M.end),
  course: text(M.courseMissing, L.courseMaxLength, M.courseTooLong),
  /** Optional for an online class. */
  room: z.string({ error: M.roomMissing }).trim().max(L.roomMaxLength, M.roomTooLong),
  teacher: text(M.teacherMissing, L.teacherMaxLength, M.teacherTooLong),
  kind: z.enum(SESSION_KINDS, { error: M.kind }),
  mode: z.enum(SESSION_MODES, { error: M.mode }),
  meetUrl: z
    .string({ error: M.meetUrlInvalid })
    .trim()
    .max(L.meetUrlMaxLength, M.meetUrlInvalid)
    .nullable(),
  notes: z.string({ error: M.notesTooLong }).trim().max(L.notesMaxLength, M.notesTooLong).nullable(),
  /** Weight of an exam in the course grade; ignored for other kinds. */
  coefficient: z
    .number({ error: M.coefficient })
    .gt(0, M.coefficient)
    .max(L.maxCoefficient, M.coefficient)
    .nullable(),
};

/** POST /admin/timetable/slots: a new class of the weekly timetable. */
export const createSlotSchema = z.object({
  weekday: fields.weekday,
  start: fields.start,
  end: fields.end,
  course: fields.course,
  room: fields.room.optional(),
  teacher: fields.teacher,
  kind: fields.kind.optional(),
  mode: fields.mode.optional(),
  meetUrl: fields.meetUrl.optional(),
  notes: fields.notes.optional(),
  coefficient: fields.coefficient.optional(),
});

/** PATCH /admin/timetable/slots/:slotId: the fields to change (at least one). */
export const updateSlotSchema = z
  .object(fields)
  .partial()
  .refine((body) => Object.values(body).some((value) => value !== undefined), M.nothingToUpdate);

export type CreateSlotInput = z.infer<typeof createSlotSchema>;
export type UpdateSlotInput = z.infer<typeof updateSlotSchema>;
