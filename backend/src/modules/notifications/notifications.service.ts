import { notFound, unauthorized } from '../../lib/http-error';
import { UserModel } from '../users/user.model';
import { NotificationModel, toNotificationJson, type NotificationJson } from './notification.model';

/** The app shows one list without paging: older notifications are left out. */
export const MAX_NOTIFICATIONS = 100;

/** Greets a student who has never had a notification (see [welcomeIfNew]). */
export const WELCOME = {
  key: 'welcome',
  category: 'community',
  label: 'CampusPulse',
  title: 'Welcome to CampusPulse',
  body:
    'Your timetable, rides, jobs and grades now live in one place. ' +
    'Campus alerts such as **room changes** and **new grades** will show up here.',
  isUrgent: false,
  attachment: null,
  link: null,
} as const;

/**
 * Gives a brand-new student a single unread "Welcome" notification, so the
 * feed and the Home bell are not empty on their first visit. Students who
 * already have notifications (like the seeded demo student) never get it.
 */
async function welcomeIfNew(userId: string): Promise<void> {
  if (await NotificationModel.exists({ userId })) return;
  // A valid token for a deleted account: treat it as an expired session.
  if (!(await UserModel.exists({ _id: userId }))) throw unauthorized();

  const { key, ...content } = WELCOME;
  // Upsert on the unique (userId, key) index: two first requests at the same
  // time still create only one welcome notification.
  await NotificationModel.updateOne(
    { userId, key },
    { $setOnInsert: { ...content, isRead: false, receivedAt: new Date() } },
    { upsert: true },
  );
}

/** The student's notifications, newest first. */
export async function listNotifications(userId: string): Promise<NotificationJson[]> {
  await welcomeIfNew(userId);
  const items = await NotificationModel.find({ userId })
    .sort({ receivedAt: -1, _id: -1 })
    .limit(MAX_NOTIFICATIONS)
    .lean();
  return items.map(toNotificationJson);
}

/**
 * Marks one of the student's notifications as read (already read is fine).
 * Someone else's notification answers 404, exactly like a missing one.
 */
export async function markAsRead(userId: string, id: string): Promise<void> {
  const result = await NotificationModel.updateOne({ userId, key: id }, { $set: { isRead: true } });
  if (result.matchedCount === 0) throw notFound('Notification not found.');
}

/** Marks every notification of the student as read. */
export async function markAllAsRead(userId: string): Promise<void> {
  await NotificationModel.updateMany({ userId, isRead: false }, { $set: { isRead: true } });
}
