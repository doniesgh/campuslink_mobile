import { addDays, calendarDate, isoWeekday } from '../timetable/calendar';

/** The campus is in Tunisia: UTC+1 all year (no daylight saving). */
const CAMPUS_UTC_OFFSET_MS = 60 * 60 * 1000;

/** Current time. Tests replace `clock.now` to pin "now". */
export const clock = { now: (): Date => new Date() };

/**
 * A moment relative to the day of the request, in campus time: `inDays`
 * days from today (negative for the past), or the next `weekday`
 * (1 = Monday ... 7 = Sunday, never today), at `time` ('HH:mm').
 * Stored this way so demo dates never go stale.
 */
export interface RelativeTime {
  inDays?: number | null;
  weekday?: number | null;
  time: string;
}

/** The campus calendar date at [now] (a Date at UTC midnight). */
export function campusToday(now: Date): Date {
  const local = new Date(now.getTime() + CAMPUS_UTC_OFFSET_MS);
  return calendarDate(local.getUTCFullYear(), local.getUTCMonth() + 1, local.getUTCDate());
}

/** The instant when campus clocks show [time] ('HH:mm') on [day]. */
export function campusInstant(day: Date, time: string): Date {
  const [hours = 0, minutes = 0] = time.split(':').map(Number);
  return new Date(
    Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), hours, minutes) -
      CAMPUS_UTC_OFFSET_MS,
  );
}

/** The instant [at] stands for when today (campus time) is [today]. */
export function resolveRelativeTime(at: RelativeTime, today: Date): Date {
  const days =
    at.weekday != null ? (at.weekday - isoWeekday(today) + 7) % 7 || 7 : (at.inDays ?? 0);
  return campusInstant(addDays(today, days), at.time);
}
