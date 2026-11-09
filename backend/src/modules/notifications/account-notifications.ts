import type { Types } from 'mongoose';

import { ROLE_LABELS, UserModel, type UserRole } from '../users/user.model';
import { NotificationModel } from './notification.model';

/** Category and badge of the notifications about accounts. */
const ACCOUNT = { category: 'account', label: 'Account' } as const;

/** What an admin changed on someone's account (only the changes the user is told about). */
export interface AccountChanges {
  role?: UserRole;
  email?: string;
  password?: boolean;
}

/**
 * Tells [userId] that an admin changed their role, email or password: one
 * body line per change. Urgent when the password changed (they must sign in
 * again). Does nothing when there is nothing to tell.
 */
export async function notifyAccountUpdated(
  userId: Types.ObjectId | string,
  changes: AccountChanges,
): Promise<void> {
  const lines: string[] = [];
  if (changes.role) lines.push(`Your role is now: **${ROLE_LABELS[changes.role]}**.`);
  if (changes.email) lines.push(`Your sign-in email is now **${changes.email}**.`);
  if (changes.password) {
    lines.push('An administrator changed your password: sign in with the new one.');
  }
  if (lines.length === 0) return;

  await NotificationModel.create({
    userId,
    ...ACCOUNT,
    title: 'Your account was updated',
    body: lines.join('\n'),
    isUrgent: changes.password === true,
    link: { destination: 'profile', id: null },
  });
}

/**
 * Tells every admin that [user] signed up in the app. The notification
 * opens the new account in the admin's user management.
 */
export async function notifyAdminsOfSignup(user: {
  _id: Types.ObjectId;
  displayName: string;
  email: string;
}): Promise<void> {
  const admins = await UserModel.find({ role: 'admin' }).select('_id').lean();
  if (admins.length === 0) return;

  const receivedAt = new Date();
  await NotificationModel.insertMany(
    admins.map((admin) => ({
      userId: admin._id,
      ...ACCOUNT,
      title: `New account: ${user.displayName}`,
      body: `**${user.email}** just signed up.`,
      receivedAt,
      isUrgent: false,
      link: { destination: 'adminUsers', id: user._id.toHexString() },
    })),
  );
}
