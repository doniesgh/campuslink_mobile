import { isObjectIdOrHexString, type Types } from 'mongoose';

import { badRequest, conflict, notFound } from '../../lib/http-error';
import { hashPassword, revokeAllSessions } from '../auth/auth.service';
import { RefreshTokenModel } from '../auth/refresh-token.model';
import { RideModel } from '../carpool/carpool.model';
import { AssignmentSubmissionModel, CourseAttendanceModel } from '../courses/courses.model';
import { ForumPostModel } from '../forum/forum-post.model';
import { IdeaVoteModel } from '../forum/idea-vote.model';
import { LostItemRequestModel } from '../forum/lost-item-request.model';
import { LostItemModel } from '../forum/lost-item.model';
import { TranscriptModel } from '../grades/transcript.model';
import { JobApplicationModel } from '../jobs/jobs.model';
import { notifyAccountUpdated } from '../notifications/account-notifications';
import { NotificationModel } from '../notifications/notification.model';
import { StudentProfileModel } from '../profile/profile.model';
import {
  ROLE_LABELS,
  USER_ROLES,
  UserModel,
  type UserDocument,
  type UserRole,
} from '../users/user.model';
import type { CreateUserInput, ListUsersQuery, UpdateUserInput } from './admin.schemas';
import { recordAudit } from './audit.service';
import { accentInsensitivePattern, searchWords } from './search';

const USER_NOT_FOUND = 'User not found.';
// The same messages as the error handler gives for a unique-index race.
export const EMAIL_TAKEN = 'An account with this email already exists.';
export const STUDENT_ID_TAKEN = 'This ENT ID is already in use.';
const OWN_ACCOUNT_FIELDS = 'On your own account, you can only change your name, email and ENT ID.';
const OWN_ACCOUNT_DELETE = "You can't delete your own account.";

/** Who is acting: the signed-in admin, and their IP address for the audit log. */
export interface AdminContext {
  actorId: string;
  ip: string | null;
}

/** What the API sends for an account in the admin screens. */
export interface ManagedUserJson {
  id: string;
  email: string;
  studentId: string | null;
  displayName: string;
  role: UserRole;
  isEmailVerified: boolean;
  createdAt: string;
}

export const toManagedUserJson = (user: UserDocument): ManagedUserJson => ({
  id: user.id as string,
  email: user.email,
  studentId: user.studentId ?? null,
  displayName: user.displayName,
  role: user.role,
  isEmailVerified: user.isEmailVerified,
  createdAt: user.createdAt.toISOString(),
});

export interface UsersPage {
  items: ManagedUserJson[];
  total: number;
  page: number;
  limit: number;
}

/** Sorts names like people read them: case and accents ignored ("élodie" next to "Elodie"). */
const NAME_COLLATION = { locale: 'fr', strength: 1 };

/**
 * Every word of [q] must appear in the name, email or ENT ID, whatever its
 * case and accents ("helene" finds "Hélène").
 */
function usersFilter({ q, role }: Pick<ListUsersQuery, 'q' | 'role'>): Record<string, unknown> {
  const filter: Record<string, unknown> = {};
  if (role) filter.role = role;
  const words = searchWords(q);
  if (words.length > 0) {
    filter.$and = words.map((word) => {
      const pattern = new RegExp(accentInsensitivePattern(word), 'i');
      return { $or: [{ displayName: pattern }, { email: pattern }, { studentId: pattern }] };
    });
  }
  return filter;
}

/** One page of accounts, sorted by name (then id, so pages never overlap). */
export async function listUsers({ q, role, page, limit }: ListUsersQuery): Promise<UsersPage> {
  const filter = usersFilter({ q, role });
  const [users, total] = await Promise.all([
    UserModel.find(filter)
      .collation(NAME_COLLATION)
      .sort({ displayName: 1, _id: 1 })
      .skip((page - 1) * limit)
      .limit(limit),
    UserModel.countDocuments(filter),
  ]);
  return { items: users.map(toManagedUserJson), total, page, limit };
}

/** How many accounts there are, in total and per role (every role is there, 0 when none). */
export async function userStats(): Promise<{ total: number; byRole: Record<UserRole, number> }> {
  const counts = await UserModel.aggregate<{ _id: string | null; count: number }>([
    { $group: { _id: '$role', count: { $sum: 1 } } },
  ]);
  const byRole = Object.fromEntries(USER_ROLES.map((role) => [role, 0])) as Record<
    UserRole,
    number
  >;
  let total = 0;
  for (const { _id, count } of counts) {
    // Accounts from before roles existed are students (see backfillRoles).
    const role = USER_ROLES.find((r) => r === _id) ?? 'student';
    byRole[role] += count;
    total += count;
  }
  return { total, byRole };
}

/** The account [id], or 404 (an id that isn't an ObjectId is just as unknown). */
async function findUser(id: string): Promise<UserDocument> {
  const user = isObjectIdOrHexString(id) ? await UserModel.findById(id) : null;
  if (!user) throw notFound(USER_NOT_FOUND);
  return user;
}

export async function getUser(id: string): Promise<ManagedUserJson> {
  return toManagedUserJson(await findUser(id));
}

/** 409 when [email] or [studentId] belongs to an account other than [exceptId]. */
async function assertAvailable(
  { email, studentId }: { email?: string; studentId?: string | null },
  exceptId?: Types.ObjectId,
): Promise<void> {
  const others = exceptId ? { _id: { $ne: exceptId } } : {};
  if (email && (await UserModel.exists({ email, ...others }))) throw conflict(EMAIL_TAKEN);
  if (studentId && (await UserModel.exists({ studentId, ...others }))) {
    throw conflict(STUDENT_ID_TAKEN);
  }
}

/**
 * Creates an account. Its email counts as verified (the admin vouches for
 * it), and no email is sent.
 */
export async function createUser(
  input: CreateUserInput,
  ctx: AdminContext,
): Promise<ManagedUserJson> {
  await assertAvailable(input);
  const user = await UserModel.create({
    email: input.email,
    displayName: input.displayName,
    studentId: input.studentId ?? undefined,
    role: input.role,
    isEmailVerified: true,
    passwordHash: await hashPassword(input.password),
  });
  await recordAudit({
    ...ctx,
    action: 'user.create',
    summary: `Created the ${ROLE_LABELS[user.role].toLowerCase()} account ${user.email}`,
    targetId: user.id as string,
    metadata: { role: user.role },
  });
  return toManagedUserJson(user);
}

type UserField = keyof UpdateUserInput;

/** How each field is named in the audit summary ("Updated Sarra Mansouri (name, password)"). */
const FIELD_LABELS: Record<UserField, string> = {
  displayName: 'name',
  email: 'email',
  studentId: 'ENT ID',
  role: 'role',
  password: 'password',
  isEmailVerified: 'email verification',
};

/** What an admin may change on their own account (so they can't demote or lock themselves out). */
const OWN_ACCOUNT_EDITABLE: ReadonlySet<UserField> = new Set(['displayName', 'email', 'studentId']);

/** The fields of [input] that really change [user] (sending the current value changes nothing). */
function changedFields(user: UserDocument, input: UpdateUserInput): UserField[] {
  const changed: UserField[] = [];
  if (input.displayName !== undefined && input.displayName !== user.displayName) {
    changed.push('displayName');
  }
  if (input.email !== undefined && input.email !== user.email) changed.push('email');
  if (input.studentId !== undefined && input.studentId !== (user.studentId ?? null)) {
    changed.push('studentId');
  }
  if (input.role !== undefined && input.role !== user.role) changed.push('role');
  if (input.password !== undefined) changed.push('password');
  if (input.isEmailVerified !== undefined && input.isEmailVerified !== user.isEmailVerified) {
    changed.push('isEmailVerified');
  }
  return changed;
}

/**
 * Changes an account. A new password signs the user out on every device.
 * The user is notified when their role, email or password changes (unless
 * the admin edits their own account, where only the name, email and ENT ID
 * can change). Nothing to change: the account is sent back as it is.
 */
export async function updateUser(
  id: string,
  input: UpdateUserInput,
  ctx: AdminContext,
): Promise<ManagedUserJson> {
  const user = await findUser(id);
  const isOwnAccount = user._id.equals(ctx.actorId);
  const changed = changedFields(user, input);
  if (isOwnAccount && changed.some((field) => !OWN_ACCOUNT_EDITABLE.has(field))) {
    throw badRequest(OWN_ACCOUNT_FIELDS);
  }
  if (changed.length === 0) return toManagedUserJson(user);

  const has = (field: UserField) => changed.includes(field);
  await assertAvailable(
    {
      email: has('email') ? input.email : undefined,
      studentId: has('studentId') ? input.studentId : undefined,
    },
    user._id,
  );

  const previous = { displayName: user.displayName, role: user.role };
  if (input.displayName !== undefined) user.displayName = input.displayName;
  if (input.email !== undefined) user.email = input.email;
  // No ENT ID is stored as a missing field: the sparse unique index skips it.
  if (input.studentId !== undefined) user.studentId = input.studentId ?? undefined;
  if (input.role !== undefined) user.role = input.role;
  if (input.isEmailVerified !== undefined) user.isEmailVerified = input.isEmailVerified;
  if (input.password !== undefined) user.passwordHash = await hashPassword(input.password);
  await user.save();
  if (has('password')) await revokeAllSessions(user._id);

  await recordAudit({
    ...ctx,
    action: 'user.update',
    summary:
      changed.length === 1 && has('role')
        ? `Changed the role of ${previous.displayName} to ${ROLE_LABELS[user.role]}`
        : `Updated ${previous.displayName} (${changed.map((f) => FIELD_LABELS[f]).join(', ')})`,
    targetId: user.id as string,
    metadata: {
      changes: changed,
      ...(has('role') ? { role: { from: previous.role, to: user.role } } : {}),
    },
  });

  if (!isOwnAccount) {
    try {
      await notifyAccountUpdated(user._id, {
        role: has('role') ? user.role : undefined,
        email: has('email') ? user.email : undefined,
        password: has('password'),
      });
    } catch (err) {
      // The account is already changed: a notification problem must not fail the request.
      console.error('[notifications] Could not tell a user about an account change:', err);
    }
  }
  return toManagedUserJson(user);
}

/**
 * Removes everything that belongs to the account [userId]: sessions,
 * notifications, attendance, lab submissions, job applications, idea votes,
 * lost & found requests, transcript and profile. The rides it drives are
 * deleted and the seats it booked on other rides become free again. Its
 * forum posts and lost & found notices stay, under their author name, with
 * no link to the account.
 */
async function deleteAccountData(userId: Types.ObjectId): Promise<void> {
  await Promise.all([
    RefreshTokenModel.deleteMany({ userId }),
    NotificationModel.deleteMany({ userId }),
    CourseAttendanceModel.deleteMany({ userId }),
    AssignmentSubmissionModel.deleteMany({ userId }),
    JobApplicationModel.deleteMany({ userId }),
    IdeaVoteModel.deleteMany({ userId }),
    LostItemRequestModel.deleteMany({ userId }),
    TranscriptModel.deleteMany({ userId }),
    StudentProfileModel.deleteMany({ userId }),
    ForumPostModel.updateMany({ authorId: userId }, { $set: { authorId: null } }),
    LostItemModel.updateMany({ reporterId: userId }, { $set: { reporterId: null } }),
  ]);
  await RideModel.deleteMany({ driverId: userId });
  await RideModel.updateMany(
    { 'seats.passengerId': userId },
    {
      $set: {
        'seats.$[seat].status': 'free',
        'seats.$[seat].passengerId': null,
        'seats.$[seat].passengerName': null,
      },
    },
    { arrayFilters: [{ 'seat.passengerId': userId }] },
  );
}

/** Deletes an account and its data (see [deleteAccountData]). Not the admin's own account. */
export async function deleteUser(id: string, ctx: AdminContext): Promise<void> {
  const user = await findUser(id);
  if (user._id.equals(ctx.actorId)) throw badRequest(OWN_ACCOUNT_DELETE);

  // The account goes last: if a step fails, the admin can simply delete it again.
  await deleteAccountData(user._id);
  await user.deleteOne();
  await recordAudit({
    ...ctx,
    action: 'user.delete',
    summary: `Deleted the account of ${user.displayName} (${user.email})`,
    targetId: user.id as string,
    metadata: { email: user.email, role: user.role },
  });
}
