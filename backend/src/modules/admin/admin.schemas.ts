import { z } from 'zod';

import { USER_ROLES } from '../users/user.model';

// Messages are shown as-is in the app's admin screens.

/** At most this many lines in one check (`dryRun: true`) of a user import. */
export const MAX_IMPORT_CHECK_ROWS = 1000;
/** At most this many accounts created by one import. */
export const MAX_IMPORT_ROWS = 50;

/** An ENT ID: 3 to 20 letters or digits, stored in capitals. */
export const STUDENT_ID_PATTERN = /^[A-Z0-9]{3,20}$/;
const STUDENT_ID_MESSAGE = 'ENT ID: 3 to 20 letters or digits';
const ROLE_MESSAGE = 'Role: not recognised (student, teacher, admin, alumni or company)';

const role = z.enum(USER_ROLES, { error: ROLE_MESSAGE });

const displayName = z
  .string({ error: 'Enter a name' })
  .trim()
  .min(1, 'Enter a name')
  .max(80, 'Name: too long (at most 80 characters)');

const email = z
  .string({ error: 'Enter an email' })
  .trim()
  .toLowerCase()
  .pipe(z.email('Enter a valid email'));

const password = z
  .string({ error: 'Choose a password' })
  .min(8, 'Use at least 8 characters')
  .max(128, 'Use at most 128 characters');

const studentId = z
  .string({ error: STUDENT_ID_MESSAGE })
  .trim()
  .toUpperCase()
  .regex(STUDENT_ID_PATTERN, STUDENT_ID_MESSAGE);

/** An ENT ID, or null / "" for none. */
const optionalStudentId = z.preprocess(
  (value) => (value === '' ? null : value),
  studentId.nullable(),
);

const PAGE_MESSAGE = 'Pass a page number of 1 or more';
const LIMIT_MESSAGE = 'Pass a limit between 1 and 100';

const page = z.coerce
  .number({ error: PAGE_MESSAGE })
  .int(PAGE_MESSAGE)
  .min(1, PAGE_MESSAGE)
  .default(1);

const limit = (fallback: number) =>
  z.coerce
    .number({ error: LIMIT_MESSAGE })
    .int(LIMIT_MESSAGE)
    .min(1, LIMIT_MESSAGE)
    .max(100, LIMIT_MESSAGE)
    .default(fallback);

/** `GET /admin/users?q=&role=&page=&limit=` */
export const listUsersQuerySchema = z.object({
  q: z
    .string({ error: 'Search with one piece of text' })
    .trim()
    .max(100, 'The search is too long')
    .optional(),
  role: z.preprocess((value) => (value === '' ? undefined : value), role.optional()),
  page,
  limit: limit(20),
});

/** `GET /admin/audit?action=&page=&limit=`: `action` is exact, or a prefix ending with `*`. */
export const auditQuerySchema = z.object({
  action: z
    .string({ error: 'Filter on one action' })
    .trim()
    .max(60, 'The action filter is too long')
    .optional(),
  page,
  limit: limit(30),
});

/** `POST /admin/users` */
export const createUserSchema = z.object({
  displayName,
  email,
  password,
  studentId: optionalStudentId.optional(),
  role: role.default('student'),
});

/** `PATCH /admin/users/:id`: only the fields to change. */
export const updateUserSchema = z
  .object({
    displayName: displayName.optional(),
    email: email.optional(),
    studentId: optionalStudentId.optional(),
    role: role.optional(),
    password: password.optional(),
    isEmailVerified: z
      .boolean({ error: 'isEmailVerified must be true or false' })
      .optional(),
  })
  .refine((input) => Object.values(input).some((value) => value !== undefined), {
    message: "There's nothing to save.",
  });

/**
 * One cell of an imported line. Checked row by row by the import service
 * (to report every problem), so anything text-like is accepted here.
 */
const cell = z
  .union([z.string(), z.number(), z.null()], { error: 'Each cell of the file must be text' })
  .optional();

const importRowSchema = z.object(
  {
    /** The line number in the admin's file, echoed back in the problems. */
    row: z
      .number({ error: 'row must be a line number' })
      .int('row must be a line number')
      .min(1, 'row must be a line number')
      .optional(),
    displayName: cell,
    email: cell,
    password: cell,
    studentId: cell,
    role: cell,
  },
  { error: 'Each line of the file must be an object' },
);

/** `POST /admin/users/import` */
export const importUsersSchema = z
  .object({
    dryRun: z.boolean({ error: 'dryRun must be true (check) or false (import)' }),
    users: z
      .array(importRowSchema, { error: 'Send the lines of the file in users' })
      .min(1, 'The file has no accounts.'),
  })
  .superRefine(({ dryRun, users }, ctx) => {
    if (dryRun && users.length > MAX_IMPORT_CHECK_ROWS) {
      ctx.addIssue({ code: 'custom', message: `At most ${MAX_IMPORT_CHECK_ROWS} lines per check.` });
    }
    if (!dryRun && users.length > MAX_IMPORT_ROWS) {
      ctx.addIssue({ code: 'custom', message: `At most ${MAX_IMPORT_ROWS} accounts per import.` });
    }
  });

const assistCell = z.union([z.string(), z.number(), z.null()], {
  error: 'Each cell of the file must be text',
});

/**
 * `POST /admin/users/import/assist`: the first lines of the file (the service
 * keeps 12) and the distinct values of short columns, emails and passwords
 * masked by the app.
 */
export const importAssistSchema = z.object({
  lines: z
    .array(z.array(assistCell, { error: 'Each line of the file must be a list of cells' }), {
      error: 'Send the first lines of the file in lines',
    })
    .min(1, 'Send the first lines of the file in lines')
    .max(50, 'Send at most 50 lines'),
  values: z
    .array(
      z.object({
        column: z
          .number({ error: 'column must be a column number' })
          .int('column must be a column number')
          .min(0, 'column must be a column number'),
        values: z.array(assistCell, { error: 'values must be a list of cells' }),
      }),
      { error: 'values must be a list of columns' },
    )
    .default([]),
});

export type ListUsersQuery = z.output<typeof listUsersQuerySchema>;
export type AuditQuery = z.output<typeof auditQuerySchema>;
export type CreateUserInput = z.output<typeof createUserSchema>;
export type UpdateUserInput = z.output<typeof updateUserSchema>;
export type ImportUsersInput = z.output<typeof importUsersSchema>;
export type ImportRowInput = ImportUsersInput['users'][number];
export type ImportAssistInput = z.output<typeof importAssistSchema>;
