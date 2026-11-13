/**
 * Wall-clock helpers for the campus timezone. Tunisia is UTC+1 all year
 * (no daylight saving since 2009), so a fixed offset is enough.
 */
const CAMPUS_UTC_OFFSET_MS = 60 * 60 * 1000;

/** [now] shifted so that its UTC getters read the campus wall clock. */
const campusClock = (now: Date) => new Date(now.getTime() + CAMPUS_UTC_OFFSET_MS);

/**
 * The instant at [hour]:[minute] campus time, [dayOffset] days after the
 * campus day of [now] (0 = today, 1 = tomorrow).
 */
export function atCampusTime(now: Date, dayOffset: number, hour: number, minute: number): Date {
  const clock = campusClock(now);
  const wallClock = Date.UTC(
    clock.getUTCFullYear(),
    clock.getUTCMonth(),
    clock.getUTCDate() + dayOffset,
    hour,
    minute,
  );
  return new Date(wallClock - CAMPUS_UTC_OFFSET_MS);
}
