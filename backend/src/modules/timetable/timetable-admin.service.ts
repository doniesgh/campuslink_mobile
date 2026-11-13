import { randomBytes } from 'node:crypto';

import { HttpError, notFound, unprocessable } from '../../lib/http-error';
import { VALIDATION_ERROR } from '../../lib/validate';
import {
  MEET_URL_PATTERN,
  SLOT_LIMITS,
  SLOT_MESSAGES,
  type CreateSlotInput,
  type UpdateSlotInput,
} from './timetable-admin.schemas';
import { CLASS_GROUP } from './timetable.data';
import {
  TimetableTemplateModel,
  type SessionKind,
  type SessionMode,
  type TimetableSlot,
} from './timetable.model';

// Admins manage the weekly timetable of the class group (there is a single
// one for now, see classGroupOf): the same classes every week. Students and
// teachers read it through /api/timetable.

/** The code of a 409 for a class that clashes with others. */
export const TIMETABLE_CONFLICT = 'TIMETABLE_CONFLICT';

/** What the admin API sends for a class of the weekly timetable. */
export interface SlotJson {
  id: string;
  /** 1 = Monday ... 7 = Sunday. */
  weekday: number;
  start: string;
  end: string;
  course: string;
  /** '' for an online class without a room. */
  room: string;
  teacher: string;
  kind: SessionKind;
  mode: SessionMode;
  meetUrl: string | null;
  notes: string | null;
  coefficient: number | null;
  lectureNumber: number | null;
  lectureCount: number | null;
}

export interface SlotListJson {
  classGroup: string;
  /** By weekday, then start time. */
  items: SlotJson[];
}

/** Why a class clashes with [slot]: the same room, or the same teacher, at overlapping times. */
export interface SlotConflictJson {
  reason: 'room' | 'teacher';
  slot: SlotJson;
}

/** A class without its id. */
export type SlotFields = Omit<TimetableSlot, 'slotId'>;

export const toSlotJson = (s: TimetableSlot): SlotJson => ({
  id: s.slotId,
  weekday: s.weekday,
  start: s.start,
  end: s.end,
  course: s.course,
  room: s.room ?? '',
  teacher: s.teacher,
  kind: s.kind,
  mode: s.mode === 'online' ? 'online' : 'onsite',
  meetUrl: s.mode === 'online' ? (s.meetUrl ?? null) : null,
  notes: s.notes ?? null,
  coefficient: s.coefficient ?? null,
  lectureNumber: s.lectureNumber ?? null,
  lectureCount: s.lectureCount ?? null,
});

/** Minutes since midnight of 'HH:mm'. */
const minutes = (hm: string): number => Number(hm.slice(0, 2)) * 60 + Number(hm.slice(3, 5));

const sortSlots = (slots: TimetableSlot[]): TimetableSlot[] =>
  [...slots].sort((a, b) => a.weekday - b.weekday || a.start.localeCompare(b.start));

const invalid = (message: string) => unprocessable(message, undefined, VALIDATION_ERROR);

/**
 * Checks the rules between the fields of a class (each field was checked by
 * its schema) and normalises it: the Meet link only for an online class, the
 * coefficient only for an exam. Throws a 422 `VALIDATION_ERROR`.
 */
export function checkSlot(slot: SlotFields): SlotFields {
  const start = minutes(slot.start);
  const end = minutes(slot.end);
  if (end <= start) throw invalid(SLOT_MESSAGES.endBeforeStart);
  if (end - start > SLOT_LIMITS.maxDurationMinutes) throw invalid(SLOT_MESSAGES.tooLong);

  const online = slot.mode === 'online';
  const room = slot.room.trim();
  if (!online && !room) throw invalid(SLOT_MESSAGES.roomMissing);
  const meetUrl = online ? slot.meetUrl?.trim() || null : null;
  if (online && !meetUrl) throw invalid(SLOT_MESSAGES.meetUrlMissing);
  if (meetUrl && !MEET_URL_PATTERN.test(meetUrl)) throw invalid(SLOT_MESSAGES.meetUrlInvalid);

  return {
    ...slot,
    room,
    meetUrl,
    notes: slot.notes?.trim() || null,
    coefficient: slot.kind === 'exam' ? (slot.coefficient ?? null) : null,
  };
}

const sameText = (a: string, b: string): boolean =>
  a.trim().toLowerCase() === b.trim().toLowerCase();

/**
 * The classes of [slots] that [candidate] clashes with: the same weekday at
 * overlapping times (touching is fine), in the same room or with the same
 * teacher. [exceptId] is the class being edited.
 */
export function findConflicts(
  slots: readonly TimetableSlot[],
  candidate: SlotFields,
  exceptId?: string,
): SlotConflictJson[] {
  const start = minutes(candidate.start);
  const end = minutes(candidate.end);
  const conflicts: SlotConflictJson[] = [];
  for (const other of sortSlots([...slots])) {
    if (other.slotId === exceptId || other.weekday !== candidate.weekday) continue;
    if (!(start < minutes(other.end) && minutes(other.start) < end)) continue;
    if (candidate.room && other.room && sameText(candidate.room, other.room)) {
      conflicts.push({ reason: 'room', slot: toSlotJson(other) });
    }
    if (sameText(candidate.teacher, other.teacher)) {
      conflicts.push({ reason: 'teacher', slot: toSlotJson(other) });
    }
  }
  return conflicts;
}

function assertNoConflicts(slots: readonly TimetableSlot[], candidate: SlotFields, exceptId?: string) {
  const conflicts = findConflicts(slots, candidate, exceptId);
  if (conflicts.length > 0) {
    throw new HttpError(
      409,
      'This class clashes with another class of the timetable',
      { conflicts },
      TIMETABLE_CONFLICT,
    );
  }
}

/** Defaults for slots saved before online classes existed (lean reads skip them). */
const withDefaults = (s: TimetableSlot): TimetableSlot => ({
  ...s,
  room: s.room ?? '',
  mode: s.mode === 'online' ? 'online' : 'onsite',
  meetUrl: s.meetUrl ?? null,
  notes: s.notes ?? null,
  coefficient: s.coefficient ?? null,
  lectureNumber: s.lectureNumber ?? null,
  lectureCount: s.lectureCount ?? null,
});

/** 'Génie Logiciel & Archi' -> 'genie-logiciel-archi' (at most 24 characters). */
function slug(text: string): string {
  const value = text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .slice(0, 24)
    .replace(/^-+|-+$/g, '');
  return value || 'class';
}

/**
 * A new id, never used by [taken]: readable and stable (it never changes, even
 * when the course is renamed). Session ids are built from it ('algo-1f3a-2026-11-9').
 */
function newSlotId(course: string, taken: ReadonlySet<string>): string {
  for (;;) {
    const id = `${slug(course)}-${randomBytes(2).toString('hex')}`;
    if (!taken.has(id)) return id;
  }
}

/**
 * The classes of the class group. Gives a unique id to the classes that share
 * one (a template saved before the admin screens existed) and saves that.
 */
async function loadSlots(): Promise<TimetableSlot[]> {
  const template = await TimetableTemplateModel.findOne({ classGroup: CLASS_GROUP }).lean();
  const slots = (template?.slots ?? []).map(withDefaults);
  const seen = new Set<string>();
  let renamed = false;
  for (const slot of slots) {
    if (seen.has(slot.slotId)) {
      slot.slotId = newSlotId(slot.course, new Set([...seen, ...slots.map((s) => s.slotId)]));
      renamed = true;
    }
    seen.add(slot.slotId);
  }
  if (renamed) {
    await TimetableTemplateModel.updateOne({ classGroup: CLASS_GROUP }, { $set: { slots } });
  }
  return slots;
}

/** GET /admin/timetable/slots: every class of the week. */
export async function listSlots(): Promise<SlotListJson> {
  const slots = await loadSlots();
  return { classGroup: CLASS_GROUP, items: sortSlots(slots).map(toSlotJson) };
}

/** Adds a class to the weekly timetable. 422 for invalid data, 409 for a clash. */
export async function createSlot(input: CreateSlotInput): Promise<TimetableSlot> {
  const slots = await loadSlots();
  const fields = checkSlot({
    weekday: input.weekday,
    start: input.start,
    end: input.end,
    course: input.course,
    room: input.room ?? '',
    teacher: input.teacher,
    kind: input.kind ?? 'lecture',
    mode: input.mode ?? 'onsite',
    meetUrl: input.meetUrl ?? null,
    notes: input.notes ?? null,
    coefficient: input.coefficient ?? null,
    lectureNumber: null,
    lectureCount: null,
  });
  assertNoConflicts(slots, fields);
  const slot: TimetableSlot = {
    slotId: newSlotId(fields.course, new Set(slots.map((s) => s.slotId))),
    ...fields,
  };
  await TimetableTemplateModel.updateOne(
    { classGroup: CLASS_GROUP },
    { $push: { slots: slot } },
    { upsert: true },
  );
  return slot;
}

const notInTimetable = () => notFound('This class is not in the timetable.');

/**
 * Changes the fields sent of the class [slotId] (the others stay). The result
 * is checked like a new class. Returns the class before and after.
 */
export async function updateSlot(
  slotId: string,
  input: UpdateSlotInput,
): Promise<{ before: TimetableSlot; after: TimetableSlot }> {
  const slots = await loadSlots();
  const before = slots.find((s) => s.slotId === slotId);
  if (!before) throw notInTimetable();

  const changes = Object.fromEntries(
    Object.entries(input).filter(([, value]) => value !== undefined),
  ) as Partial<SlotFields>;
  const { slotId: _id, ...current } = before;
  const fields = checkSlot({ ...current, ...changes });
  assertNoConflicts(slots, fields, slotId);

  const after: TimetableSlot = { slotId, ...fields };
  const result = await TimetableTemplateModel.updateOne(
    { classGroup: CLASS_GROUP, 'slots.slotId': slotId },
    { $set: { 'slots.$': after } },
  );
  if (result.matchedCount === 0) throw notInTimetable();
  return { before, after };
}

/** Removes the class [slotId] from the weekly timetable and returns it. */
export async function deleteSlot(slotId: string): Promise<TimetableSlot> {
  const slots = await loadSlots();
  const slot = slots.find((s) => s.slotId === slotId);
  if (!slot) throw notInTimetable();
  await TimetableTemplateModel.updateOne(
    { classGroup: CLASS_GROUP },
    { $pull: { slots: { slotId } } },
  );
  return slot;
}
