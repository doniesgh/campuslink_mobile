import mongoose from 'mongoose';

import { connectMongo, disconnectMongo } from '../src/db/mongo';
import { setMailer } from '../src/modules/auth/mailer';
import { signAccessToken } from '../src/modules/auth/tokens';
import { UserModel, type UserDocument, type UserRole } from '../src/modules/users/user.model';

let studentCount = 0;

export interface TestAccount {
  user: UserDocument;
  token: string;
  auth: { Authorization: string };
}

export interface AccountOverrides {
  email?: string;
  displayName?: string;
  studentId?: string;
  role?: UserRole;
}

/**
 * Creates a verified student (or another [overrides.role]) directly in the
 * database (fast: no bcrypt, no HTTP) and returns it with ready-to-use auth
 * headers.
 */
export async function createStudent(overrides: AccountOverrides = {}): Promise<TestAccount> {
  studentCount += 1;
  const user = await UserModel.create({
    email: overrides.email ?? `student${studentCount}@campus.test`,
    displayName: overrides.displayName ?? `Student ${studentCount}`,
    studentId: overrides.studentId,
    role: overrides.role ?? 'student',
    passwordHash: 'not-used-in-these-tests',
    isEmailVerified: true,
  });
  const token = signAccessToken(user.id);
  return { user, token, auth: { Authorization: `Bearer ${token}` } };
}

/** Creates a verified admin, like [createStudent]. */
export async function createAdmin(
  overrides: Omit<AccountOverrides, 'role'> = {},
): Promise<TestAccount> {
  return createStudent({
    email: `admin${studentCount + 1}@campus.test`,
    displayName: `Admin ${studentCount + 1}`,
    ...overrides,
    role: 'admin',
  });
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
