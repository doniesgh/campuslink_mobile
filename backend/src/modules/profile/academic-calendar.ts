/**
 * ESPRIT academic calendar, with the same rules as the app
 * (lib/features/profile/domain/academic_calendar.dart): the year starts in
 * September, odd semesters run September–January and even ones
 * February–August. Dates are read in Tunisia's time zone.
 */

/** Tunisia is on UTC+1 all year (no daylight saving time). */
const TUNIS_OFFSET_MS = 60 * 60 * 1000;

/** Year and month (1–12) of [date] in Tunisia. */
function tunisYearMonth(date: Date): { year: number; month: number } {
  const local = new Date(date.getTime() + TUNIS_OFFSET_MS);
  return { year: local.getUTCFullYear(), month: local.getUTCMonth() + 1 };
}

/** Start year of the academic year containing [date] (Nov 2026 → 2026, Mar 2027 → 2026). */
export function academicYearStartFor(date: Date): number {
  const { year, month } = tunisYearMonth(date);
  return month >= 9 ? year : year - 1;
}

/** 2024 → "2024–2025" (en dash, as printed on the student card). */
export const formatAcademicYear = (startYear: number): string =>
  `${startYear}–${startYear + 1}`;

/**
 * Overall semester number of a student in [yearOfStudy] (1-based) on [date].
 * A 4th-year student is in S7 in the fall and S8 in the spring.
 */
export function semesterFor(yearOfStudy: number, date: Date): number {
  const { month } = tunisYearMonth(date);
  const spring = month >= 2 && month < 9;
  return (yearOfStudy - 1) * 2 + (spring ? 2 : 1);
}

/** Student cards stay valid until 30 September after the academic year ends ('YYYY-MM-DD'). */
export const cardValidUntil = (academicYearStart: number): string =>
  `${academicYearStart + 1}-09-30`;

/** The instant at a Tunisia wall-clock time ([month] is 1–12). */
export const tunisTime = (year: number, month: number, day: number, hour = 0, minute = 0): Date =>
  new Date(Date.UTC(year, month - 1, day, hour, minute) - TUNIS_OFFSET_MS);

/**
 * The request date used by the grades and profile routes. Tests replace
 * `clock.now` to pin it.
 */
export const clock = { now: (): Date => new Date() };
