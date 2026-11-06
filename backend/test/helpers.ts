import mongoose from 'mongoose';

import { connectMongo, disconnectMongo } from '../src/db/mongo';
import { setMailer } from '../src/modules/auth/mailer';
import { signAccessToken } from '../src/modules/auth/tokens';
import { UserModel, type UserDocument } from '../src/modules/users/user.model';

let studentCount = 0;

/**
 * Creates a verified student directly in the database (fast: no bcrypt, no
 * HTTP) and returns it with ready-to-use auth headers.
 */
export async function createStudent(
  overrides: { email?: string; displayName?: string; studentId?: string } = {},
): Promise<{ user: UserDocument; token: string; auth: { Authorization: string } }> {
  studentCount += 1;
  const user = await UserModel.create({
    email: overrides.email ?? `student${studentCount}@campus.test`,
    displayName: overrides.displayName ?? `Student ${studentCount}`,
    studentId: overrides.studentId,
    passwordHash: 'not-used-in-these-tests',
    isEmailVerified: true,
  });
  const token = signAccessToken(user.id);
  return { user, token, auth: { Authorization: `Bearer ${token}` } };
}

/** Connects to this worker's test database, empty, with the unique indexes built. */
export async function connectTestDb(): Promise<void> {
  await connectMongo(process.env.MONGO_URL as string);
  await mongoose.connection.dropDatabase();
  await Promise.all(Object.values(mongoose.models).map((m) => m.syncIndexes()));
}

/** Empties every collection but keeps the indexes. */
export async function clearTestDb(): Promise<void> {
  await Promise.all(
    Object.values(mongoose.connection.collections).map((c) => c.deleteMany({})),
  );
}

export async function closeTestDb(): Promise<void> {
  await mongoose.connection.dropDatabase();
  await disconnectMongo();
}

export interface SentMail {
  codes: { to: string; code: string }[];
  resets: { to: string; code: string }[];
}

/** Captures the auth emails (into [sent], or a new record) instead of sending them. */
export function captureMail(sent: SentMail = { codes: [], resets: [] }): SentMail {
  setMailer({
    async sendVerificationCode(to, code) {
      sent.codes.push({ to, code });
    },
    async sendPasswordResetCode(to, code) {
      sent.resets.push({ to, code });
    },
  });
  return sent;
}
