import {
  addDays,
  calendarDate,
  daysBetween,
  formatCalendarDate,
  isoWeekday,
  weekStart,
} from './calendar';
import { CLASS_GROUP } from './timetable.data';
import {
  TimetableTemplateModel,
  type SessionKind,
  type TimetableSlot,
} from './timetable.model';

// What the API sends (the shapes the app's timetable_models.dart reads).
// Dates are 'YYYY-MM-DD' and times wall-clock 'HH:mm': the app builds the
// DateTimes itself, so 08:30 stays 08:30 whatever the time zones.

export interface ClassSessionJson {
  id: string;
  course: string;
  room: string;
  teacher: string;
  date: string;
  start: string;
  end: string;
  kind: SessionKind;
  lectureNumber: number | null;
  lectureCount: number | null;
  coefficient: number | null;
  notes: string | null;
}

export interface TimetableDayJson {
  date: string;
  /** 1-based week of the semester, or null outside a semester. */
  semesterWeek: number | null;
  /** Sorted by start time. */
  sessions: ClassSessionJson[];
}

export interface TimetableWeekJson {
  /** Monday. */
  start: string;
  /** Monday to Sunday. */
  days: TimetableDayJson[];
  /** 1 or 2, or null outside a semester. */
  semester: number | null;
  classGroup: string;
}

/** The student's class group. There is a single one for now. */
export function classGroupOf(_userId: string): string {
  return CLASS_GROUP;
}

// Mock academic calendar (same rules as the app's mock): S1 starts on
// 15 September, S2 on 2 February, 16 weeks each.
const SEMESTER_WEEKS = 16;

/** 1-based week of the semester on [date], or null outside a semester. */
export function semesterWeek(date: Date): number | null {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + 1;
  const start =
    month >= 9
      ? calendarDate(year, 9, 15)
      : month >= 2
        ? calendarDate(year, 2, 2)
        : calendarDate(year - 1, 9, 15);
  const days = daysBetween(start, date);
  if (days < 0) return null;
  const week = Math.floor(days / 7) + 1;
  return week <= SEMESTER_WEEKS ? week : null;
}

/** 1 or 2 during a semester, else null. */
export function semesterOf(date: Date): number | null {
  if (semesterWeek(date) === null) return null;
  const month = date.getUTCMonth() + 1;
  return month >= 9 || month < 2 ? 1 : 2;
}

async function slotsOf(classGroup: string): Promise<TimetableSlot[]> {
  const template = await TimetableTemplateModel.findOne({ classGroup }).lean();
  return template?.slots ?? [];
}

function buildDay(slots: TimetableSlot[], date: Date): TimetableDayJson {
  const weekday = isoWeekday(date);
  // Same session ids as the app's mock: 'algo-2026-11-5'.
  const key = `${date.getUTCFullYear()}-${date.getUTCMonth() + 1}-${date.getUTCDate()}`;
  const day = formatCalendarDate(date);
  const sessions = slots
    .filter((s) => s.weekday === weekday)
    .map(
      (s): ClassSessionJson => ({
        id: `${s.slotId}-${key}`,
        course: s.course,
        room: s.room,
        teacher: s.teacher,
        date: day,
        start: s.start,
        end: s.end,
        kind: s.kind,
        lectureNumber: s.lectureNumber ?? null,
        lectureCount: s.lectureCount ?? null,
        coefficient: s.coefficient ?? null,
        notes: s.notes ?? null,
      }),
    )
    // 'HH:mm' strings sort like the times they hold.
    .sort((a, b) => a.start.localeCompare(b.start));
  return { date: day, semesterWeek: semesterWeek(date), sessions };
}

/** The student's sessions on [date]. */
export async function getDay(userId: string, date: Date): Promise<TimetableDayJson> {
  return buildDay(await slotsOf(classGroupOf(userId)), date);
}

/** The week (Monday to Sunday) containing [date]. */
export async function getWeek(userId: string, date: Date): Promise<TimetableWeekJson> {
  const classGroup = classGroupOf(userId);
  const slots = await slotsOf(classGroup);
  const monday = weekStart(date);
  const dates = Array.from({ length: 7 }, (_, i) => addDays(monday, i));
  return {
    start: formatCalendarDate(monday),
    days: dates.map((d) => buildDay(slots, d)),
    // The semester of the first weekday that is in one.
    semester:
      dates
        .slice(0, 5)
        .map(semesterOf)
        .find((s) => s !== null) ?? null,
    classGroup,
  };
}
