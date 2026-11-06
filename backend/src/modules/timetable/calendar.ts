// Calendar dates (no time of day) are Dates at UTC midnight, so no time zone
// or daylight-saving change can move them to another day.

const DAY_MS = 24 * 60 * 60 * 1000;

export const calendarDate = (year: number, month: number, day: number): Date =>
  new Date(Date.UTC(year, month - 1, day));

/** 'YYYY-MM-DD' */
export const formatCalendarDate = (date: Date): string => date.toISOString().slice(0, 10);

/** The date for 'YYYY-MM-DD', or null when it is malformed or does not exist (2026-02-30). */
export function parseCalendarDate(value: string): Date | null {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  const date = calendarDate(Number(match[1]), Number(match[2]), Number(match[3]));
  return formatCalendarDate(date) === value ? date : null;
}

export const addDays = (date: Date, days: number): Date => new Date(date.getTime() + days * DAY_MS);

/** Whole days from [from] to [to] (negative when [to] is earlier). */
export const daysBetween = (from: Date, to: Date): number =>
  Math.round((to.getTime() - from.getTime()) / DAY_MS);

/** 1 = Monday ... 7 = Sunday (like Dart's DateTime.weekday). */
export const isoWeekday = (date: Date): number => ((date.getUTCDay() + 6) % 7) + 1;

/** Monday of the week containing [date]. */
export const weekStart = (date: Date): Date => addDays(date, 1 - isoWeekday(date));
