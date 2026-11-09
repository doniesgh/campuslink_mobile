import request from 'supertest';

import { createApp } from '../src/app';
import { AuditLogModel } from '../src/modules/admin/audit-log.model';
import { UserModel } from '../src/modules/users/user.model';
import {
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  type TestAccount,
} from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

type Row = Record<string, unknown>;

const importUsers = (auth: { Authorization: string }, dryRun: unknown, users: unknown) =>
  request(app).post('/api/admin/users/import').set(auth).send({ dryRun, users });

/** [count] valid lines: user1@import.test, user2@import.test... */
const validRows = (count: number): Row[] =>
  Array.from({ length: count }, (_, i) => ({
    row: i + 2,
    displayName: `Imported User ${i + 1}`,
    email: `user${i + 1}@import.test`,
    password: `Pass-word-${i + 1}`,
    studentId: `IMP${String(i + 1).padStart(4, '0')}`,
    role: 'student',
  }));

let admin: TestAccount;
beforeEach(async () => {
  admin = await createAdmin({ email: 'admin@campus.test' });
});

/** The file of the problem table: one line per problem, plus valid lines. */
async function fileWithEveryProblem(): Promise<Row[]> {
  await createStudent({ email: 'taken@campus.test', studentId: 'TAKEN01' });
  return [
    { row: 2, displayName: 'Sarra Mansouri', email: 'sarra@import.test', password: 'Kp7m-x2Qa', studentId: '221JMT0101', role: 'student' },
    { row: 3, displayName: '', email: 'missing-name@import.test', password: 'password123' },
    { row: 4, displayName: 'x'.repeat(81), email: 'long-name@import.test', password: 'password123' },
    { row: 5, displayName: 'No Email', password: 'password123' },
    { row: 6, displayName: 'Bad Email', email: 'not-an-email', password: 'password123' },
    { row: 7, displayName: 'Same Email', email: ' SARRA@import.test ', password: 'password123' },
    { row: 8, displayName: 'Taken Email', email: 'Taken@campus.test', password: 'password123' },
    { row: 9, displayName: 'Bad Id', email: 'bad-id@import.test', password: 'password123', studentId: 'A-1' },
    { row: 10, displayName: 'Same Id', email: 'same-id@import.test', password: 'password123', studentId: '221jmt0101' },
    { row: 11, displayName: 'Taken Id', email: 'taken-id@import.test', password: 'password123', studentId: 'taken01' },
    { row: 12, displayName: 'Bad Role', email: 'bad-role@import.test', password: 'password123', role: 'boss' },
    { row: 13, displayName: 'No Password', email: 'no-password@import.test', password: '  ' },
    { row: 14, displayName: 'Short Password', email: 'short@import.test', password: 'short' },
    { row: 15, displayName: 'Teacher', email: 'teacher@import.test', password: 'password123', role: 'Teacher', studentId: null },
    { row: 16, displayName: '', email: 'nope', password: 'x', studentId: '!', role: 'x' },
  ];
}

describe('POST /api/admin/users/import (dry run)', () => {
  test('reports every problem of every line and creates nothing', async () => {
    const users = await fileWithEveryProblem();

    const res = await importUsers(admin.auth, true, users).expect(200);

    expect(res.body).toEqual({
      dryRun: true,
      valid: 2,
      problems: [
        { row: 3, field: 'displayName', code: 'REQUIRED', message: 'Name: missing' },
        { row: 4, field: 'displayName', code: 'TOO_LONG', message: 'Name: too long (at most 80 characters)' },
        { row: 5, field: 'email', code: 'REQUIRED', message: 'Email: missing' },
        { row: 6, field: 'email', code: 'INVALID_EMAIL', message: 'Email: not a valid address' },
        { row: 7, field: 'email', code: 'DUPLICATE_EMAIL', message: 'Email: already on another line of the file' },
        { row: 8, field: 'email', code: 'EMAIL_TAKEN', message: 'Email: an account already uses it' },
        { row: 9, field: 'studentId', code: 'INVALID_STUDENT_ID', message: 'ENT ID: 3 to 20 letters or digits' },
        { row: 10, field: 'studentId', code: 'DUPLICATE_STUDENT_ID', message: 'ENT ID: already on another line of the file' },
        { row: 11, field: 'studentId', code: 'STUDENT_ID_TAKEN', message: 'ENT ID: an account already uses it' },
        { row: 12, field: 'role', code: 'INVALID_ROLE', message: 'Role: not recognised (student, teacher, admin or alumni)' },
        { row: 13, field: 'password', code: 'REQUIRED', message: 'Password: missing' },
        { row: 14, field: 'password', code: 'PASSWORD_TOO_SHORT', message: 'Password: at least 8 characters' },
        // Several problems on one line: all of them, in column order.
        { row: 16, field: 'displayName', code: 'REQUIRED', message: 'Name: missing' },
        { row: 16, field: 'email', code: 'INVALID_EMAIL', message: 'Email: not a valid address' },
        { row: 16, field: 'password', code: 'PASSWORD_TOO_SHORT', message: 'Password: at least 8 characters' },
        { row: 16, field: 'studentId', code: 'INVALID_STUDENT_ID', message: 'ENT ID: 3 to 20 letters or digits' },
        { row: 16, field: 'role', code: 'INVALID_ROLE', message: 'Role: not recognised (student, teacher, admin or alumni)' },
      ],
    });
    expect(await UserModel.countDocuments()).toBe(2);
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });

  test('a valid file has no problems', async () => {
    const res = await importUsers(admin.auth, true, validRows(3)).expect(200);
    expect(res.body).toEqual({ dryRun: true, valid: 3, problems: [] });
    expect(await UserModel.countDocuments()).toBe(1);
  });

  test('numbers the lines from 1 when the rows have no number', async () => {
    const res = await importUsers(admin.auth, true, [
      { displayName: 'A', email: 'a@import.test', password: 'password123' },
      { displayName: 'B', email: 'a@import.test', password: 'password123' },
    ]).expect(200);
    expect(res.body.problems).toEqual([
      { row: 2, field: 'email', code: 'DUPLICATE_EMAIL', message: 'Email: already on another line of the file' },
    ]);
  });

  test('also flags a too long password', async () => {
    const res = await importUsers(admin.auth, true, [
      { row: 2, displayName: 'A', email: 'a@import.test', password: 'x'.repeat(129) },
    ]).expect(200);
    expect(res.body.problems).toEqual([
      { row: 2, field: 'password', code: 'TOO_LONG', message: 'Password: too long (at most 128 characters)' },
    ]);
  });

  test('checks up to 1000 lines (a body bigger than 100 kB), not more', async () => {
    const thousand = validRows(1000);
    expect(JSON.stringify(thousand).length).toBeGreaterThan(100 * 1024);

    const res = await importUsers(admin.auth, true, thousand).expect(200);
    expect(res.body).toEqual({ dryRun: true, valid: 1000, problems: [] });

    await importUsers(admin.auth, true, validRows(1001)).expect(422, {
      message: 'At most 1000 lines per check.',
    });
  });
});

describe('POST /api/admin/users/import', () => {
  test('creates every account, verified, and records one audit entry', async () => {
    const users: Row[] = [
      { row: 2, displayName: ' Sarra Mansouri ', email: 'Sarra.Mansouri@Import.test', password: 'Kp7m-x2Qa-9zTb', studentId: '221jmt0101', role: 'student' },
      { row: 3, displayName: 'Amira Ben Salah', email: 'amira@import.test', password: 'Teach-2026!', role: 'TEACHER' },
      { row: 4, displayName: 'Selim Rekik', email: 'selim@import.test', password: 12345678, studentId: 2019001, role: '' },
    ];

    const res = await importUsers(admin.auth, false, users).expect(201);

    expect(res.body).toEqual({
      dryRun: false,
      created: [
        { id: expect.any(String), email: 'sarra.mansouri@import.test', studentId: '221JMT0101', displayName: 'Sarra Mansouri', role: 'student', isEmailVerified: true, createdAt: expect.any(String) },
        { id: expect.any(String), email: 'amira@import.test', studentId: null, displayName: 'Amira Ben Salah', role: 'teacher', isEmailVerified: true, createdAt: expect.any(String) },
        { id: expect.any(String), email: 'selim@import.test', studentId: '2019001', displayName: 'Selim Rekik', role: 'student', isEmailVerified: true, createdAt: expect.any(String) },
      ],
    });
    await request(app)
      .post('/api/auth/login')
      .send({ identifier: '221JMT0101', password: 'Kp7m-x2Qa-9zTb' })
      .expect(200);
    await request(app)
      .post('/api/auth/login')
      .send({ identifier: 'selim@import.test', password: '12345678' })
      .expect(200);

    const entries = await AuditLogModel.find().lean();
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({
      action: 'user.import',
      summary: 'Imported 3 accounts',
      targetId: null,
      metadata: {
        count: 3,
        emails: ['sarra.mansouri@import.test', 'amira@import.test', 'selim@import.test'],
      },
    });
    expect(JSON.stringify(entries[0])).not.toMatch(/Kp7m|Teach-2026|password/i);
  });

  test('says "1 account" for a single line', async () => {
    await importUsers(admin.auth, false, validRows(1)).expect(201);
    expect((await AuditLogModel.findOne())?.summary).toBe('Imported 1 account');
  });

  test('imports nothing when any line has a problem', async () => {
    const users = [...validRows(2), { row: 9, displayName: 'Bad', email: 'bad', password: 'password123' }];

    const res = await importUsers(admin.auth, false, users).expect(422);

    expect(res.body).toEqual({
      message: 'The file has errors, so nothing was imported.',
      problems: [{ row: 9, field: 'email', code: 'INVALID_EMAIL', message: 'Email: not a valid address' }],
    });
    expect(await UserModel.countDocuments()).toBe(1);
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });

  test('imports at most 50 accounts at once', async () => {
    await importUsers(admin.auth, false, validRows(51)).expect(422, {
      message: 'At most 50 accounts per import.',
    });
    await importUsers(admin.auth, false, validRows(1001)).expect(422, {
      message: 'At most 50 accounts per import.',
    });
    expect(await UserModel.countDocuments()).toBe(1);
  });

  test('removes the accounts it inserted when the insert fails part-way', async () => {
    const original = UserModel.insertMany.bind(UserModel);
    const spy = jest
      .spyOn(UserModel, 'insertMany')
      .mockImplementationOnce((async (docs: object[]) => {
        // Another request takes the third email between the check and the insert.
        await original(docs.slice(0, 2));
        throw Object.assign(new Error('E11000 duplicate key'), {
          code: 11000,
          keyPattern: { email: 1 },
        });
      }) as never);
    try {
      await importUsers(admin.auth, false, validRows(3)).expect(409, {
        message: 'An account with this email already exists.',
      });
    } finally {
      spy.mockRestore();
    }
    expect(await UserModel.countDocuments()).toBe(1);
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });

  test.each([
    [{ users: validRows(1) }, 'dryRun must be true (check) or false (import)'],
    [{ dryRun: 'yes', users: validRows(1) }, 'dryRun must be true (check) or false (import)'],
    [{ dryRun: true }, 'Send the lines of the file in users'],
    [{ dryRun: true, users: [] }, 'The file has no accounts.'],
    [{ dryRun: true, users: ['a line'] }, 'Each line of the file must be an object'],
    [{ dryRun: true, users: [{ email: { a: 1 } }] }, 'Each cell of the file must be text'],
    [{ dryRun: true, users: [{ row: 0 }] }, 'row must be a line number'],
  ])('answers 422 for %j', async (body, message) => {
    const res = await request(app)
      .post('/api/admin/users/import')
      .set(admin.auth)
      .send(body)
      .expect(422);
    expect(res.body).toEqual({ message });
  });

  test('is for admins only, even with a big body', async () => {
    const { auth } = await createStudent({ role: 'teacher' });
    await importUsers(auth, true, validRows(1000)).expect(403);
  });
});
