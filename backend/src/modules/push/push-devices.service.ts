import type { Types } from 'mongoose';

import { unauthorized } from '../../lib/http-error';
import { UserModel } from '../users/user.model';
import { PushDeviceModel } from './push-device.model';
import type { RegisterDeviceInput } from './push.schemas';

/** An account keeps at most this many phones; registering one more forgets the oldest. */
export const MAX_DEVICES_PER_USER = 10;

type UserId = Types.ObjectId | string;

/**
 * Registers (or refreshes) the phone [token] for the push notifications of
 * [userId]. The app calls it after every sign-in and whenever FCM gives it a
 * new token. A token registered by another account moves to this one: on a
 * shared phone, the last account signed in gets the pushes. Beyond
 * [MAX_DEVICES_PER_USER] phones, the ones seen least recently are forgotten.
 */
export async function registerDevice(
  userId: string,
  { token, platform }: RegisterDeviceInput,
): Promise<void> {
  // A valid token for a deleted account: treat it as an expired session.
  if (!(await UserModel.exists({ _id: userId }))) throw unauthorized();

  await PushDeviceModel.updateOne(
    { token },
    { $set: { userId, platform, lastSeenAt: new Date() } },
    { upsert: true },
  );

  const forgotten = await PushDeviceModel.find({ userId })
    .sort({ lastSeenAt: -1, _id: -1 })
    .skip(MAX_DEVICES_PER_USER)
    .select('_id')
    .lean();
  if (forgotten.length > 0) {
    await PushDeviceModel.deleteMany({ _id: { $in: forgotten.map((device) => device._id) } });
  }
}

/**
 * Stops pushing [userId]'s notifications to the phone [token]. Another
 * account's phone is left alone, and an unknown token is not an error.
 */
export async function unregisterDevice(userId: UserId, token: string): Promise<void> {
  await PushDeviceModel.deleteOne({ userId, token });
}

/** Stops pushing to every phone of [userId] (they register again at the next sign-in). */
export async function removeAllDevices(userId: UserId): Promise<void> {
  await PushDeviceModel.deleteMany({ userId });
}
