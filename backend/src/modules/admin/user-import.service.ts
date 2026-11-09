import { Types } from 'mongoose';
import { z } from 'zod';

import { unprocessable } from '../../lib/http-error';
import { hashPassword } from '../auth/auth.service';
import { USER_ROLES, UserModel, type UserRole } from '../users/user.model';
import { STUDENT_ID_PATTERN, type ImportRowInput, type ImportUsersInput } from './admin.schemas';
import { toManagedUserJson, type AdminContext, type ManagedUserJson } from './admin-users.service';
import { recordAudit } from './audit.service';

/** The columns of an imported line, in the order their problems are listed. */
const IMPORT_FIELDS = ['displayName', 'email', 'password', 'studentId', 'role'] as const;
type ImportField = (typeof IMPORT_FIELDS)[number];

export type ImportProblemCode =
  | 'REQUIRED'
  | 'TOO_LONG'
  | 'INVALID_EMAIL'
  | 'DUPLICATE_EMAIL'
  | 'EMAIL_TAKEN'
  | 'INVALID_STUDENT_ID'
  | 'DUPLICATE_STUDENT_ID'
  | 'STUDENT_ID_TAKEN'
  | 'INVALID_ROLE'
  | 'PASSWORD_TOO_SHORT';

/** One problem of one line, shown next to that line in the app. */
export interface ImportProblem {
  row: number;
  field: ImportField;
  code: ImportProblemCode;
  message: string;
}

/** The message of each (field, code) pair. Shown as-is in the app. */
const MESSAGES: Record<string, string> = {
  'displayName:REQUIRED': 'Name: missing',
  'displayName:TOO_LONG': 'Name: too long (at most 80 characters)',
  'email:REQUIRED': 'Email: missing',
  'email:INVALID_EMAIL': 'Email: not a valid address',
  'email:DUPLICATE_EMAIL': 'Email: already on another line of the file',
  'email:EMAIL_TAKEN': 'Email: an account already uses it',
  'password:REQUIRED': 'Password: missing',
  'password:PASSWORD_TOO_SHORT': 'Password: at least 8 characters',
  'password:TOO_LONG': 'Password: too long (at most 128 characters)',
  'studentId:INVALID_STUDENT_ID': 'ENT ID: 3 to 20 letters or digits',
  'studentId:DUPLICATE_STUDENT_ID': 'ENT ID: already on another line of the file',
  'studentId:STUDENT_ID_TAKEN': 'ENT ID: an account already uses it',
  'role:INVALID_ROLE': 'Role: not recognised (student, teacher, admin or alumni)',
};

const MAX_NAME_LENGTH = 80;
const MIN_PASSWORD_LENGTH = 8;
const MAX_PASSWORD_LENGTH = 128;
/** The audit entry of an import lists this many emails at most. */
const AUDITED_EMAILS = 20;

const emailFormat = z.email();

/** A line once normalised (trimmed, email in lowercase, ENT ID in capitals). */
interface ImportLine {
  row: number;
  displayName: string;
  email: string;
  password: string;
  studentId: string | null;
  role: UserRole;
  /** At most one problem per field: the first one found. */
  problems: Partial<Record<ImportField, ImportProblemCode>>;
}

const cellText = (value: string | number | null | undefined): string =>
  value == null ? '' : String(value);

/** Normalises one line and finds the problems that don't need the other lines. */
function readLine(input: ImportRowInput, index: number): ImportLine {
  const problems: ImportLine['problems'] = {};

  const displayName = cellText(input.displayName).trim();
  if (!displayName) problems.displayName = 'REQUIRED';
  else if (displayName.length > MAX_NAME_LENGTH) problems.displayName = 'TOO_LONG';

  const email = cellText(input.email).trim().toLowerCase();
  if (!email) problems.email = 'REQUIRED';
  else if (!emailFormat.safeParse(email).success) problems.email = 'INVALID_EMAIL';

  // Passwords are kept exactly as typed (like at sign-up).
  const password = cellText(input.password);
  if (!password.trim()) problems.password = 'REQUIRED';
  else if (password.length < MIN_PASSWORD_LENGTH) problems.password = 'PASSWORD_TOO_SHORT';
  else if (password.length > MAX_PASSWORD_LENGTH) problems.password = 'TOO_LONG';

  const studentId = cellText(input.studentId).trim().toUpperCase() || null;
  if (studentId && !STUDENT_ID_PATTERN.test(studentId)) problems.studentId = 'INVALID_STUDENT_ID';

  const roleText = cellText(input.role).trim().toLowerCase() || 'student';
  const role = USER_ROLES.find((r) => r === roleText);
  if (!role) problems.role = 'INVALID_ROLE';

  return {
    row: input.row ?? index + 1,
    displayName,
    email,
    password,
    studentId,
    role: role ?? 'student',
    problems,
  };
}

/**
 * Flags a value already seen on an earlier line ([duplicate]) or already
 * used by an account ([taken]). Lines with a problem on [field] are skipped.
 */
async function flagDuplicatesAndTaken(
  lines: ImportLine[],
  field: 'email' | 'studentId',
  duplicate: ImportProblemCode,
  taken: ImportProblemCode,
): Promise<void> {
  const candidates = lines.filter((line) => line[field] && !line.problems[field]);
  const values = [...new Set(candidates.map((line) => line[field] as string))];
  const existing = await UserModel.find({ [field]: { $in: values } })
    .select(field)
    .lean();
  const used = new Set(existing.map((user) => user[field]));

  const seen = new Set<string>();
  for (const line of candidates) {
    const value = line[field] as string;
    if (seen.has(value)) line.problems[field] = duplicate;
    else if (used.has(value)) line.problems[field] = taken;
    seen.add(value);
  }
}

/** Every line, normalised, with all its problems (one database query per checked column). */
async function checkLines(rows: ImportRowInput[]): Promise<ImportLine[]> {
  const lines = rows.map(readLine);
  await flagDuplicatesAndTaken(lines, 'email', 'DUPLICATE_EMAIL', 'EMAIL_TAKEN');
  await flagDuplicatesAndTaken(lines, 'studentId', 'DUPLICATE_STUDENT_ID', 'STUDENT_ID_TAKEN');
  return lines;
}

const problemsOf = (lines: ImportLine[]): ImportProblem[] =>
  lines.flatMap((line) =>
    IMPORT_FIELDS.flatMap((field) => {
      const code = line.problems[field];
      return code ? [{ row: line.row, field, code, message: MESSAGES[`${field}:${code}`] }] : [];
    }),
  );

export type ImportResult =
  | { dryRun: true; valid: number; problems: ImportProblem[] }
  | { dryRun: false; created: ManagedUserJson[] };

/**
 * Checks (`dryRun: true`) or imports a list of accounts, all or nothing.
 * Every line is checked and every problem reported. An import with problems
 * answers 422 with them and creates nothing. Imported accounts are verified
 * and get no email.
 */
export async function importUsers(
  { dryRun, users }: ImportUsersInput,
  ctx: AdminContext,
): Promise<ImportResult> {
  const lines = await checkLines(users);
  const problems = problemsOf(lines);
  if (dryRun) {
    const valid = lines.filter((line) => Object.keys(line.problems).length === 0).length;
    return { dryRun: true, valid, problems };
  }
  if (problems.length > 0) {
    throw unprocessable('The file has errors, so nothing was imported.', { problems });
  }

  // Ids chosen here, so a failed import can remove exactly what it inserted.
  const docs = await Promise.all(
    lines.map(async (line) => ({
      _id: new Types.ObjectId(),
      email: line.email,
      displayName: line.displayName,
      studentId: line.studentId ?? undefined,
      role: line.role,
      isEmailVerified: true,
      passwordHash: await hashPassword(line.password),
    })),
  );
  let created;
  try {
    created = await UserModel.insertMany(docs, { ordered: true });
  } catch (err) {
    // Someone took an email or ENT ID since the check: undo the lines already inserted.
    await UserModel.deleteMany({ _id: { $in: docs.map((doc) => doc._id) } });
    throw err;
  }

  const count = created.length;
  await recordAudit({
    ...ctx,
    action: 'user.import',
    summary: `Imported ${count} ${count === 1 ? 'account' : 'accounts'}`,
    metadata: { count, emails: created.slice(0, AUDITED_EMAILS).map((user) => user.email) },
  });
  return { dryRun: false, created: created.map(toManagedUserJson) };
}
