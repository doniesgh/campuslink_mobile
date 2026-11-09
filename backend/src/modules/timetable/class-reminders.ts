import { campusInstant, campusToday, clock } from '../courses/campus-time';
import { PushDeviceModel } from '../push/push-device.model';
import { isPushOn, pushToUsers, type PushContent, type PushReport } from '../push/push.service';
import { ROLES_WITH_CLASSES, UserModel } from '../users/user.model';
import { ClassReminderModel } from './class-reminder.model';
import { CLASS_GROUP } from './timetable.data';
import type { SessionKind } from './timetable.model';
import { getClassGroupDay, type ClassSessionJson } from './timetable.service';

/** Reminders go out this many minutes before a class or an exam starts. */
export const REMINDER_LEAD_MINUTES = 15;

/**
 * The Android channel of class reminders, created by the app's
 * MainActivity.kt (`class_reminders_channel_id`). Its own channel, so people
 * can mute the reminders in Android's settings and keep the other pushes.
 */
export const CLASS_REMINDERS_CHANNEL = 'class_reminders';

/** How often the job looks for classes about to start. */
const CHECK_EVERY_MS = 60 * 1000;

const KIND_LABELS: Record<SessionKind, string> = {
  lecture: 'Lecture',
  lab: 'Lab',
  workshop: 'Workshop',
  exam: 'Exam',
};

/** The reminder of [session], starting in [minutes]: "Lecture in 15 min · 08:30–10:00 · Amphi A". */
export function reminderContent(session: ClassSessionJson, minutes: number): PushContent {
  return {
    title: session.course,
    body: [
      `${KIND_LABELS[session.kind]} in ${minutes} min`,
      `${session.start}–${session.end}`,
      session.room,
    ].join(' · '),
    // Not a notification of the feed (no id): it opens the timetable.
    data: { notificationId: '', category: 'academic', destination: 'timetable', targetId: '' },
    tag: `class-${session.id}`,
    channelId: CLASS_REMINDERS_CHANNEL,
  };
}

/** Minutes from [now] until [session] starts, rounded up (0 or less once started). */
export function minutesUntil(session: ClassSessionJson, today: Date, now: Date): number {
  return Math.ceil((campusInstant(today, session.start).getTime() - now.getTime()) / 60_000);
}

/** The people who follow classes and have a phone to remind. */
async function recipients(): Promise<string[]> {
  const withPhone = await PushDeviceModel.distinct('userId');
  if (withPhone.length === 0) return [];
  const users = await UserModel.find({
    _id: { $in: withPhone },
    role: { $in: ROLES_WITH_CLASSES },
  })
    .select('_id')
    .lean();
  // Everyone is in the same class group for now (see classGroupOf).
  return users.map((user) => user._id.toHexString());
}

const isDuplicateKey = (err: unknown): boolean =>
  typeof err === 'object' && err !== null && (err as { code?: unknown }).code === 11000;

/** True for the first caller only: the reminder of [sessionId] is ours to send. */
async function claim(sessionId: string): Promise<boolean> {
  try {
    await ClassReminderModel.create({ key: sessionId });
    return true;
  } catch (err) {
    if (isDuplicateKey(err)) return false;
    throw err;
  }
}

/** What one check did: the sessions reminded, and the pushes. */
export interface ReminderRun {
  reminded: Array<{ sessionId: string; course: string; start: string }>;
  report: PushReport;
}

/**
 * Pushes a reminder for every session of today (campus time) starting in
 * the next [REMINDER_LEAD_MINUTES] minutes, to the students and teachers
 * who have a phone. Each session is reminded once. Does nothing when push
 * is off, and claims nothing while nobody can be reminded.
 */
export async function sendClassReminders(now: Date = clock.now()): Promise<ReminderRun> {
  const run: ReminderRun = { reminded: [], report: { devices: 0, sent: 0, failed: 0, removed: 0 } };
  if (!isPushOn()) return run;

  const today = campusToday(now);
  const due = (await getClassGroupDay(CLASS_GROUP, today)).sessions
    .map((session) => ({ session, minutes: minutesUntil(session, today, now) }))
    .filter(({ minutes }) => minutes > 0 && minutes <= REMINDER_LEAD_MINUTES);
  if (due.length === 0) return run;

  const userIds = await recipients();
  if (userIds.length === 0) return run;

  for (const { session, minutes } of due) {
    if (!(await claim(session.id))) continue;
    const report = await pushToUsers(userIds, reminderContent(session, minutes));
    run.reminded.push({ sessionId: session.id, course: session.course, start: session.start });
    run.report.devices += report.devices;
    run.report.sent += report.sent;
    run.report.failed += report.failed;
    run.report.removed += report.removed;
  }
  return run;
}

/**
 * Checks every minute for classes about to start (started by server.ts once
 * push is on). Returns a function that stops it. Runs never overlap, and a
 * failed run is logged, never thrown.
 */
export function startClassReminders(): () => void {
  if (!isPushOn()) return () => {};
  let running = false;
  const check = async () => {
    if (running) return;
    running = true;
    try {
      const { reminded, report } = await sendClassReminders();
      for (const { course, start } of reminded) {
        console.info(`[push] Class reminder: ${course} at ${start}.`);
      }
      if (reminded.length > 0) {
        console.info(`[push] ${report.sent} of ${report.devices} reminder push(es) sent.`);
      }
    } catch (err) {
      console.error('[push] Class reminders failed:', err);
    } finally {
      running = false;
    }
  };
  const timer = setInterval(() => void check(), CHECK_EVERY_MS);
  timer.unref();
  void check();
  console.info(`[push] Class reminders on: ${REMINDER_LEAD_MINUTES} min before each class.`);
  return () => clearInterval(timer);
}
