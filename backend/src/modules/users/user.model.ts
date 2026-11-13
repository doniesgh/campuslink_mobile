import { model, Schema, type HydratedDocument, type InferSchemaType } from 'mongoose';

import { DEFAULT_LOCALE, LOCALES, type Locale } from '../../lib/i18n';

/**
 * What an account can do. Sent as-is: the app reads them as its UserRole enum
 * names. `company` is a recruiter (a partner company): it posts job offers.
 */
export const USER_ROLES = ['student', 'teacher', 'admin', 'alumni', 'company'] as const;
export type UserRole = (typeof USER_ROLES)[number];

/**
 * The roles that follow classes, so have a timetable and courses. Admins run
 * the platform, alumni have graduated and companies recruit: they have neither.
 */
export const ROLES_WITH_CLASSES: readonly UserRole[] = ['student', 'teacher'];

/** How a role is written in sentences shown to people ("Your role is now: **Teacher**."). */
export const ROLE_LABELS: Record<UserRole, string> = {
  student: 'Student',
  teacher: 'Teacher',
  admin: 'Admin',
  alumni: 'Alumni',
  company: 'Company',
};

const userSchema = new Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },

    /** ENT identifier (e.g. 211JMT0428), assigned by the school. Optional at sign-up. */
    studentId: { type: String, unique: true, sparse: true, uppercase: true, trim: true },

    displayName: { type: String, required: true, trim: true },
    avatarUrl: { type: String, default: null },
    isEmailVerified: { type: Boolean, default: false },

    /** Sign-up always gives `student`; only an admin can change it (see the admin module). */
    role: { type: String, enum: USER_ROLES, default: 'student', index: true },

    /** The language of the app, and of the emails and notifications the server writes for this user. */
    locale: { type: String, enum: LOCALES, default: DEFAULT_LOCALE },

    // Secrets: never returned unless explicitly selected (.select('+field')).
    passwordHash: { type: String, required: true, select: false },
    resetCodeHash: { type: String, select: false },
    resetExpiresAt: { type: Date, select: false },
    resetAttempts: { type: Number, default: 0, select: false },
  },
  { timestamps: true },
);

export type User = InferSchemaType<typeof userSchema>;
export type UserDocument = HydratedDocument<User>;

export const UserModel = model('User', userSchema);

/**
 * Gives a role to the accounts created before roles existed (they are all
 * students). Idempotent: run at start-up and by the seed.
 * Returns the number of accounts updated.
 */
export async function backfillRoles(): Promise<number> {
  const result = await UserModel.updateMany(
    { role: { $exists: false } },
    { $set: { role: 'student' } },
  );
  return result.modifiedCount;
}

/**
 * Gives the default language (French) to the accounts created before
 * languages existed. Idempotent: run at start-up and by the seed.
 * Returns the number of accounts updated.
 */
export async function backfillLocale(): Promise<number> {
  const result = await UserModel.updateMany(
    { locale: { $exists: false } },
    { $set: { locale: DEFAULT_LOCALE } },
  );
  return result.modifiedCount;
}

/** The language of [user] (French for an account saved before languages existed). */
export const localeOfUser = (user: { locale?: string | null }): Locale =>
  LOCALES.find((locale) => locale === user.locale) ?? DEFAULT_LOCALE;

/** What the API sends for a user (the shape the app's UserModel.fromJson reads). */
export interface PublicUser {
  id: string;
  email: string;
  studentId: string | null;
  displayName: string;
  avatarUrl: string | null;
  isEmailVerified: boolean;
  role: UserRole;
  locale: Locale;
}

export const toPublicUser = (user: UserDocument): PublicUser => ({
  id: user.id,
  email: user.email,
  studentId: user.studentId ?? null,
  displayName: user.displayName,
  avatarUrl: user.avatarUrl ?? null,
  isEmailVerified: user.isEmailVerified,
  role: user.role,
  locale: localeOfUser(user),
});
