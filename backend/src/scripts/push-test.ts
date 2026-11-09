import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';
import { NotificationModel } from '../modules/notifications/notification.model';
import { closePush, initPush } from '../modules/push/fcm';
import { PushDeviceModel } from '../modules/push/push-device.model';
import { pushNotifications, pushToUsers, type PushReport } from '../modules/push/push.service';
import { addDays } from '../modules/timetable/calendar';
import {
  minutesUntil,
  REMINDER_LEAD_MINUTES,
  reminderContent,
} from '../modules/timetable/class-reminders';
import { CLASS_GROUP } from '../modules/timetable/timetable.data';
import { getClassGroupDay, type ClassSessionJson } from '../modules/timetable/timetable.service';
import { campusToday } from '../modules/courses/campus-time';
import { ROLES_WITH_CLASSES, UserModel } from '../modules/users/user.model';

/**
 * Sends a test push notification to the phones of an account:
 *
 *   npm run push:test -- <email or ENT ID>
 *   npm run push:test -- <email or ENT ID> --class
 *
 * The notification is also added to the account's feed in the app. With
 * --class, it is instead the reminder of the account's next class, as the
 * API sends it 15 minutes before (a preview: the real one still goes out). Push
 * needs FIREBASE_SERVICE_ACCOUNT_FILE (see .env.example), and a phone where
 * the account signed in to the app with notifications allowed.
 */
const USAGE = 'Usage: npm run push:test -- <email or ENT ID> [--class]';

const TEST_NOTIFICATION = {
  category: 'community',
  label: 'CampusPulse',
  title: 'Push test',
  body: 'If you can read this on your phone, push notifications work.',
  isUrgent: false,
  attachment: null,
  link: null,
} as const;

async function pushTest(identifier: string, classReminder: boolean): Promise<void> {
  await connectMongo(env.MONGO_URL);

  // Like the sign-in: an email contains "@", anything else is an ENT ID.
  const user = await UserModel.findOne(
    identifier.includes('@')
      ? { email: identifier.toLowerCase() }
      : { studentId: identifier.toUpperCase() },
  );
  if (!user) {
    console.error(`No account has the email or ENT ID "${identifier}".`);
    process.exitCode = 1;
    return;
  }

  const pushOn = await initPush();
  let report: PushReport;
  if (classReminder) {
    const next = await nextSession(new Date());
    if (!next) {
      console.error('The timetable has no class in the next 7 days.');
      process.exitCode = 1;
      return;
    }
    console.info(
      `Preview of the reminder of ${next.course} (${next.date} at ${next.start}) for ` +
        `${user.displayName} (${user.email}).`,
    );
    if (!ROLES_WITH_CLASSES.includes(user.role)) {
      console.info(`Note: a ${user.role} account never gets the real reminders (no classes).`);
    }
    report = await pushToUsers([user.id as string], reminderContent(next, REMINDER_LEAD_MINUTES));
  } else {
    const notification = await NotificationModel.create({ userId: user._id, ...TEST_NOTIFICATION });
    console.info(`Added "${TEST_NOTIFICATION.title}" to the notifications of ${user.displayName} (${user.email}).`);
    report = await pushNotifications([notification]);
  }
  console.info(
    `Report: ${report.devices} device(s), ${report.sent} sent, ${report.failed} failed, ` +
      `${report.removed} removed.`,
  );

  if (!pushOn) {
    const phones = await PushDeviceModel.countDocuments({ userId: user._id });
    console.info(
      'Push is off, so nothing was sent: see the [push] line above. ' +
        `(The account has ${phones} registered device(s).)`,
    );
  } else if (report.devices === 0) {
    console.info(
      `${user.email} has no registered device: sign in to the app on a phone ` +
        '(and allow notifications), then try again.',
    );
  } else {
    if (report.sent > 0) console.info(`Sent to ${report.sent} device(s): check the phone.`);
    if (report.removed > 0) {
      console.info(
        `${report.removed} device(s) were no longer registered with Firebase (app removed, ` +
          'or a new token) and were deleted.',
      );
    }
    if (report.failed > 0) console.info('Some sends failed: see the [push] error above.');
  }
}

/** The next session of the timetable that hasn't started at [now] (within 7 days). */
async function nextSession(now: Date): Promise<ClassSessionJson | null> {
  const today = campusToday(now);
  for (let days = 0; days < 7; days += 1) {
    const day = await getClassGroupDay(CLASS_GROUP, addDays(today, days));
    const next = day.sessions.find(
      (session) => days > 0 || minutesUntil(session, today, now) > 0,
    );
    if (next) return next;
  }
  return null;
}

function main(): void {
  const args = process.argv.slice(2);
  const classReminder = args.includes('--class');
  const identifier = args.find((arg) => !arg.startsWith('--'))?.trim();
  if (!identifier) {
    console.error(USAGE);
    process.exitCode = 1;
    return;
  }

  pushTest(identifier, classReminder)
    .catch((err: unknown) => {
      console.error('Could not send the test push:', err);
      process.exitCode = 1;
    })
    .finally(async () => {
      await closePush();
      await disconnectMongo();
    });
}

main();
