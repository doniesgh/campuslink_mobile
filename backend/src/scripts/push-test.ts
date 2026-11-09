import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';
import { NotificationModel } from '../modules/notifications/notification.model';
import { closePush, initPush } from '../modules/push/fcm';
import { PushDeviceModel } from '../modules/push/push-device.model';
import { pushNotifications } from '../modules/push/push.service';
import { UserModel } from '../modules/users/user.model';

/**
 * Sends a test push notification to the phones of an account:
 *
 *   npm run push:test -- <email or ENT ID>
 *
 * The notification is also added to the account's feed in the app. Push
 * needs FIREBASE_SERVICE_ACCOUNT_FILE (see .env.example), and a phone where
 * the account signed in to the app with notifications allowed.
 */
const USAGE = 'Usage: npm run push:test -- <email or ENT ID>';

const TEST_NOTIFICATION = {
  category: 'community',
  label: 'CampusPulse',
  title: 'Push test',
  body: 'If you can read this on your phone, push notifications work.',
  isUrgent: false,
  attachment: null,
  link: null,
} as const;

async function pushTest(identifier: string): Promise<void> {
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
  const notification = await NotificationModel.create({ userId: user._id, ...TEST_NOTIFICATION });
  console.info(`Added "${TEST_NOTIFICATION.title}" to the notifications of ${user.displayName} (${user.email}).`);

  const report = await pushNotifications([notification]);
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

function main(): void {
  const identifier = process.argv[2]?.trim();
  if (!identifier) {
    console.error(USAGE);
    process.exitCode = 1;
    return;
  }

  pushTest(identifier)
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
