import mongoose from 'mongoose';

import { connectMongo, disconnectMongo } from '../src/db/mongo';
import type { Locale } from '../src/lib/i18n';
import { setMailer } from '../src/modules/auth/mailer';
import { signAccessToken } from '../src/modules/auth/tokens';
import {
  setPushSender,
  settlePushes,
  type PushMessage,
} from '../src/modules/push/push.service';
import { UserModel, type UserDocument, type UserRole } from '../src/modules/users/user.model';

let studentCount = 0;

/** The body of a 422 from validateBody / parseQuery: the first problem, and the code. */
export const validationError = (message: string) => ({ message, code: 'VALIDATION_ERROR' });

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
  /** The password-reset codes, in order (the only email the API sends). */
  resets: { to: string; code: string }[];
  /** Every email, in order, with the language it was asked in. */
  emails: { kind: 'reset'; to: string; locale: Locale | undefined }[];
}

/** Captures the auth emails (into [sent], or a new record) instead of sending them. */
export function captureMail(sent: SentMail = { resets: [], emails: [] }): SentMail {
  setMailer({
    async sendPasswordResetCode(to, code, locale) {
      sent.resets.push({ to, code });
      sent.emails.push({ kind: 'reset', to, locale });
    },
  });
  return sent;
}

export interface CapturedPush {
  /** Every message handed to the fake FCM, in order (refused ones included). */
  messages: PushMessage[];
  /**
   * The FCM error code to answer for a token, e.g.
   * `push.errors['old-phone'] = 'messaging/registration-token-not-registered'`.
   * Tokens not listed are sent.
   */
  errors: Record<string, string>;
  /**
   * Waits until every push started in the background has been answered.
   * Account notifications push without making the request wait, so await this
   * after the request and before checking [messages] or the devices.
   */
  settle(): Promise<void>;
  /** Forgets the messages and the errors (call it in beforeEach). */
  reset(): void;
}

/**
 * Turns push on with a fake FCM that records the messages (into [captured],
 * or a new record) instead of sending them. Without it, push is off in the
 * tests, as on a server without FIREBASE_SERVICE_ACCOUNT_FILE.
 */
export function capturePush(captured?: CapturedPush): CapturedPush {
  const record: CapturedPush = captured ?? {
    messages: [],
    errors: {},
    settle: settlePushes,
    reset() {
      record.messages.length = 0;
      for (const token of Object.keys(record.errors)) delete record.errors[token];
    },
  };
  setPushSender({
    async send(messages) {
      record.messages.push(...messages);
      return messages.map((message) => {
        const code = record.errors[message.token];
        return code ? { ok: false, code, message: `Fake FCM error: ${code}` } : { ok: true };
      });
    },
  });
  return record;
}
