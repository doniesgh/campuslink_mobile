import { unauthorized } from '../../lib/http-error';
import { toPublicUser, UserModel, type PublicUser, type UserDocument } from './user.model';
import type { UpdateMeInput } from './users.schemas';

/** The signed-in user's account, or 401 when it was deleted (a valid token of a gone account). */
async function findMe(userId: string): Promise<UserDocument> {
  const user = await UserModel.findById(userId);
  if (!user) throw unauthorized();
  return user;
}

export async function getMe(userId: string): Promise<PublicUser> {
  return toPublicUser(await findMe(userId));
}

/**
 * Applies the fields of [input] the user sent (see `updateMeSchema`) and
 * returns the account. Sending the current values changes nothing.
 */
export async function updateMe(userId: string, input: UpdateMeInput): Promise<PublicUser> {
  const user = await findMe(userId);
  if (input.locale !== undefined) user.locale = input.locale;
  if (user.isModified()) await user.save();
  return toPublicUser(user);
}
