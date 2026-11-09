import request from 'supertest';
import { Types } from 'mongoose';

import { createApp } from '../src/app';
import { AuditLogModel } from '../src/modules/admin/audit-log.model';
import { RefreshTokenModel } from '../src/modules/auth/refresh-token.model';
import { RideModel } from '../src/modules/carpool/carpool.model';
import {
  AssignmentSubmissionModel,
  CourseAttendanceModel,
} from '../src/modules/courses/courses.model';
import { ForumPostModel } from '../src/modules/forum/forum-post.model';
import { IdeaVoteModel } from '../src/modules/forum/idea-vote.model';
import { LostItemRequestModel } from '../src/modules/forum/lost-item-request.model';
import { LostItemModel } from '../src/modules/forum/lost-item.model';
import { TranscriptModel } from '../src/modules/grades/transcript.model';
import { JobApplicationModel } from '../src/modules/jobs/jobs.model';
import { NotificationModel } from '../src/modules/notifications/notification.model';
import { StudentProfileModel } from '../src/modules/profile/profile.model';
import { backfillRoles, UserModel } from '../src/modules/users/user.model';
import {
  captureMail,
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  type TestAccount,
} from './helpers';

const app = createApp();
captureMail();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

type Auth = { Authorization: string };

interface ManagedUserBody {
  id: string;
  email: string;
  studentId: string | null;
  displayName: string;
  role: string;
  isEmailVerified: boolean;
  createdAt: string;
}

interface UsersPageBody {
  items: ManagedUserBody[];
  total: number;
  page: number;
  limit: number;
}

interface NotificationBody {
  id: string;
  category: string;
  label: string;
  title: string;
  body: string;
  isUrgent: boolean;
  link: { destination: string; id: string | null } | null;
}

const listUsers = async (auth: Auth, query: Record<string, string | number> = {}) =>
  (await request(app).get('/api/admin/users').query(query).set(auth).expect(200))
    .body as UsersPageBody;

const names = (page: UsersPageBody) => page.items.map((u) => u.displayName);

const patch = (auth: Auth, id: string, body: object) =>
  request(app).patch(`/api/admin/users/${id}`).set(auth).send(body);

const notificationsOf = async (auth: Auth) =>
  (await request(app).get('/api/notifications').set(auth).expect(200)).body as NotificationBody[];

const accountNotificationsOf = async (auth: Auth) =>
  (await notificationsOf(auth)).filter((n) => n.category === 'account');

const login = (identifier: string, password: string) =>
  request(app).post('/api/auth/login').send({ identifier, password });

describe('access', () => {
  test.each([
    ['get', '/api/admin/users'],
    ['get', '/api/admin/users/stats'],
    ['get', '/api/admin/users/6aee283c10aef9a35cb4bcc6'],
    ['post', '/api/admin/users'],
    ['patch', '/api/admin/users/6aee283c10aef9a35cb4bcc6'],
    ['delete', '/api/admin/users/6aee283c10aef9a35cb4bcc6'],
    ['post', '/api/admin/users/import'],
    ['get', '/api/admin/audit'],
    ['get', '/api/admin/audit/actions'],
  ] as const)('%s %s answers 401 without a token', async (method, path) => {
    const res = await request(app)[method](path).expect(401);
    expect(res.body).toEqual({ message: 'Invalid credentials or expired session.' });
  });

  test.each(['student', 'teacher', 'alumni'] as const)(
    'answers 403 to a %s, before looking at the body',
    async (role) => {
      const { auth } = await createStudent({ role });
      const forbidden = { message: 'Only administrators can do this.' };
      await request(app).get('/api/admin/users').set(auth).expect(403, forbidden);
      await request(app).get('/api/admin/users/stats').set(auth).expect(403, forbidden);
      await request(app).post('/api/admin/users').set(auth).send({}).expect(403, forbidden);
      await request(app).get('/api/admin/audit').set(auth).expect(403, forbidden);
    },
  );

  test('a demoted admin loses access at once, a promoted user gets it at once', async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    await request(app).get('/api/admin/users').set(admin.auth).expect(200);
    await request(app).get('/api/admin/users').set(student.auth).expect(403);

    await UserModel.updateOne({ _id: admin.user._id }, { role: 'teacher' });
    await UserModel.updateOne({ _id: student.user._id }, { role: 'admin' });

    await request(app).get('/api/admin/users').set(admin.auth).expect(403);
    await request(app).get('/api/admin/users').set(student.auth).expect(200);
  });

  test('answers 401 to the valid token of a deleted admin', async () => {
    const admin = await createAdmin();
    await UserModel.deleteOne({ _id: admin.user._id });
    await request(app).get('/api/admin/users').set(admin.auth).expect(401);
  });
});

describe('role on the session user', () => {
  test('register, login and /users/me send the role; sign-up ignores a role in the body', async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Eve', email: 'eve@campus.test', password: 'password123', role: 'admin' })
      .expect(201);
    expect(reg.body.user.role).toBe('student');

    const signedIn = await login('eve@campus.test', 'password123').expect(200);
    expect(signedIn.body.user.role).toBe('student');

    await UserModel.updateOne({ email: 'eve@campus.test' }, { role: 'teacher' });
    const me = await request(app)
      .get('/api/users/me')
      .set({ Authorization: `Bearer ${signedIn.body.accessToken as string}` })
      .expect(200);
    expect(me.body.role).toBe('teacher');
  });

  test('backfillRoles makes the accounts without a role students, and only them', async () => {
    const { user: teacher } = await createStudent({ role: 'teacher' });
    await UserModel.collection.insertOne({
      email: 'old@campus.test',
      displayName: 'Old Account',
      passwordHash: 'x',
      isEmailVerified: true,
    });

    expect(await backfillRoles()).toBe(1);
    expect(await backfillRoles()).toBe(0);

    expect((await UserModel.findOne({ email: 'old@campus.test' }))?.role).toBe('student');
    expect((await UserModel.findById(teacher._id))?.role).toBe('teacher');
  });
});

describe('GET /api/admin/users', () => {
  test('sends ManagedUsers sorted by name (case and accents ignored), then by id', async () => {
    const { auth } = await createAdmin({ displayName: 'Admin' });
    for (const displayName of ['Zoé Ammar', 'élodie Ben', 'Bob Smith', 'alice Martin', 'Sam Lee']) {
      await createStudent({ displayName });
    }
    const { user: secondSam } = await createStudent({ displayName: 'sam lee', studentId: '221jmt0999' });

    const page = await listUsers(auth);

    expect(names(page)).toEqual([
      'Admin',
      'alice Martin',
      'Bob Smith',
      'élodie Ben',
      'Sam Lee',
      'sam lee',
      'Zoé Ammar',
    ]);
    expect(page).toMatchObject({ total: 7, page: 1, limit: 20 });
    expect(page.items[5]).toEqual({
      id: secondSam.id,
      email: secondSam.email,
      studentId: '221JMT0999',
      displayName: 'sam lee',
      role: 'student',
      isEmailVerified: true,
      createdAt: secondSam.createdAt.toISOString(),
    });
  });

  test('pages through the accounts', async () => {
    const { auth } = await createAdmin({ displayName: 'Admin' });
    for (const displayName of ['Bea', 'Cid', 'Dan', 'Eva']) await createStudent({ displayName });

    const second = await listUsers(auth, { page: 2, limit: 2 });
    expect(names(second)).toEqual(['Cid', 'Dan']);
    expect(second).toMatchObject({ total: 5, page: 2, limit: 2 });

    const third = await listUsers(auth, { page: 3, limit: 2 });
    expect(names(third)).toEqual(['Eva']);
    expect((await listUsers(auth, { page: 4, limit: 2 })).items).toEqual([]);
  });

  test('filters by role', async () => {
    const { auth } = await createAdmin({ displayName: 'Admin' });
    await createStudent({ displayName: 'Amira', role: 'teacher' });
    await createStudent({ displayName: 'Karim', role: 'teacher' });
    await createStudent({ displayName: 'Selim', role: 'alumni' });
    await createStudent({ displayName: 'Sarra' });

    expect(names(await listUsers(auth, { role: 'teacher' }))).toEqual(['Amira', 'Karim']);
    expect(names(await listUsers(auth, { role: 'admin' }))).toEqual(['Admin']);
    expect((await listUsers(auth, { role: 'teacher' })).total).toBe(2);
    expect((await listUsers(auth, { role: '' })).total).toBe(5);
  });

  describe('search', () => {
    let auth: Auth;
    beforeEach(async () => {
      ({ auth } = await createAdmin({ displayName: 'Admin', email: 'admin@campus.test' }));
      await createStudent({
        displayName: 'Hélène Gharbi',
        email: 'helene.gharbi@campus.test',
        studentId: '221JMT0106',
      });
      await createStudent({ displayName: 'HELENE Martin', email: 'h.martin@campus.test' });
      await createStudent({
        displayName: 'Omar Ferchichi',
        email: 'omar.ferchichi@campus.test',
        studentId: '221JMT0102',
      });
      await createStudent({ displayName: 'Karim Xu', email: 'kx@campus.test', role: 'teacher' });
    });

    test('ignores case and accents, both ways', async () => {
      expect(names(await listUsers(auth, { q: 'helene' }))).toEqual([
        'Hélène Gharbi',
        'HELENE Martin',
      ]);
      expect(names(await listUsers(auth, { q: 'HÉLÈNE' }))).toEqual([
        'Hélène Gharbi',
        'HELENE Martin',
      ]);
      expect(names(await listUsers(auth, { q: 'gharbï' }))).toEqual(['Hélène Gharbi']);
    });

    test('needs every word, each in the name, email or ENT ID', async () => {
      expect(names(await listUsers(auth, { q: '  hélène   martin ' }))).toEqual(['HELENE Martin']);
      expect(names(await listUsers(auth, { q: '221jmt01' }))).toEqual([
        'Hélène Gharbi',
        'Omar Ferchichi',
      ]);
      expect(names(await listUsers(auth, { q: 'ferchichi@campus' }))).toEqual(['Omar Ferchichi']);
      expect(names(await listUsers(auth, { q: 'omar 0106' }))).toEqual([]);
      expect((await listUsers(auth, { q: '' })).total).toBe(5);
    });

    test('combines with the role filter and counts the matches', async () => {
      const page = await listUsers(auth, { q: 'campus', role: 'teacher' });
      expect(names(page)).toEqual(['Karim Xu']);
      expect(page.total).toBe(1);
    });

    test('takes special characters literally', async () => {
      // As a regular expression, "m.x" would match "Karim Xu".
      expect((await listUsers(auth, { q: 'm.x' })).total).toBe(0);
      expect(names(await listUsers(auth, { q: 'r.f' }))).toEqual(['Omar Ferchichi']);
      for (const q of ['(', '*', '[a-', '\\', '$']) {
        expect((await listUsers(auth, { q })).total).toBe(0);
      }
    });
  });

  test.each([
    [{ page: 0 }, 'Pass a page number of 1 or more'],
    [{ page: 'abc' }, 'Pass a page number of 1 or more'],
    [{ page: 1.5 }, 'Pass a page number of 1 or more'],
    [{ limit: 0 }, 'Pass a limit between 1 and 100'],
    [{ limit: 101 }, 'Pass a limit between 1 and 100'],
    [{ role: 'boss' }, 'Role: not recognised (student, teacher, admin or alumni)'],
    [{ q: 'x'.repeat(101) }, 'The search is too long'],
  ] as const)('answers 422 for %j', async (query, message) => {
    const { auth } = await createAdmin();
    const res = await request(app).get('/api/admin/users').query(query).set(auth).expect(422);
    expect(res.body).toEqual({ message });
  });

  test('answers 422 for a repeated search parameter', async () => {
    const { auth } = await createAdmin();
    await request(app)
      .get('/api/admin/users?q=a&q=b')
      .set(auth)
      .expect(422, { message: 'Search with one piece of text' });
  });
});

describe('GET /api/admin/users/stats', () => {
  test('counts every role, with 0 for the empty ones', async () => {
    const { auth } = await createAdmin();
    await createStudent();
    await createStudent();
    await createStudent({ role: 'teacher' });

    await request(app)
      .get('/api/admin/users/stats')
      .set(auth)
      .expect(200, { total: 4, byRole: { student: 2, teacher: 1, admin: 1, alumni: 0 } });
  });
});

describe('GET /api/admin/users/:id', () => {
  test('sends one account', async () => {
    const { auth } = await createAdmin();
    const { user } = await createStudent({ displayName: 'Sarra Mansouri', studentId: '221JMT0101' });

    const res = await request(app).get(`/api/admin/users/${user.id}`).set(auth).expect(200);
    expect(res.body).toEqual({
      id: user.id,
      email: user.email,
      studentId: '221JMT0101',
      displayName: 'Sarra Mansouri',
      role: 'student',
      isEmailVerified: true,
      createdAt: user.createdAt.toISOString(),
    });
  });

  test.each(['not-an-id', '123456789012', new Types.ObjectId().toHexString()])(
    'answers 404 for %s',
    async (id) => {
      const { auth } = await createAdmin();
      await request(app)
        .get(`/api/admin/users/${id}`)
        .set(auth)
        .expect(404, { message: 'User not found.' });
    },
  );
});

describe('POST /api/admin/users', () => {
  const newTeacher = {
    displayName: '  Amira Ben Salah ',
    email: 'Amira.BenSalah@Campus.test',
    password: 'Teach-2026!',
    studentId: ' t2026amira ',
    role: 'teacher',
  };

  test('creates a verified account that can sign in, and records it', async () => {
    const { auth, user: admin } = await createAdmin();

    const res = await request(app).post('/api/admin/users').set(auth).send(newTeacher).expect(201);

    expect(res.body).toEqual({
      id: expect.any(String),
      email: 'amira.bensalah@campus.test',
      studentId: 'T2026AMIRA',
      displayName: 'Amira Ben Salah',
      role: 'teacher',
      isEmailVerified: true,
      createdAt: expect.any(String),
    });
    const signedIn = await login('amira.bensalah@campus.test', 'Teach-2026!').expect(200);
    expect(signedIn.body.user).toMatchObject({ role: 'teacher', isEmailVerified: true });

    const entries = await AuditLogModel.find().lean();
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({
      action: 'user.create',
      summary: 'Created the teacher account amira.bensalah@campus.test',
      actor: { id: admin.id, displayName: admin.displayName, email: admin.email },
      targetId: res.body.id,
      metadata: { role: 'teacher' },
    });
  });

  test('makes a student without an ENT ID by default, and sends no email', async () => {
    const mail = captureMail();
    const { auth } = await createAdmin();
    const res = await request(app)
      .post('/api/admin/users')
      .set(auth)
      .send({ displayName: 'Omar', email: 'omar@campus.test', password: 'password123', studentId: null })
      .expect(201);
    expect(res.body).toMatchObject({ role: 'student', studentId: null, isEmailVerified: true });
    expect(mail.codes).toEqual([]);
  });

  test('answers 409 for a taken email (whatever the case) or ENT ID', async () => {
    const { auth } = await createAdmin();
    await createStudent({ email: 'amira.bensalah@campus.test' });
    await createStudent({ studentId: 'T2026AMIRA' });

    await request(app)
      .post('/api/admin/users')
      .set(auth)
      .send(newTeacher)
      .expect(409, { message: 'An account with this email already exists.' });
    await request(app)
      .post('/api/admin/users')
      .set(auth)
      .send({ ...newTeacher, email: 'amira2@campus.test' })
      .expect(409, { message: 'This ENT ID is already in use.' });
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });

  test.each([
    [{ displayName: '' }, 'Enter a name'],
    [{ displayName: 'x'.repeat(81) }, 'Name: too long (at most 80 characters)'],
    [{ email: undefined }, 'Enter an email'],
    [{ email: 'amira' }, 'Enter a valid email'],
    [{ password: 'short' }, 'Use at least 8 characters'],
    [{ password: 'x'.repeat(129) }, 'Use at most 128 characters'],
    [{ studentId: 'AB' }, 'ENT ID: 3 to 20 letters or digits'],
    [{ studentId: '221-JMT' }, 'ENT ID: 3 to 20 letters or digits'],
    [{ role: 'boss' }, 'Role: not recognised (student, teacher, admin or alumni)'],
  ])('answers 422 for %j', async (override, message) => {
    const { auth } = await createAdmin();
    const res = await request(app)
      .post('/api/admin/users')
      .set(auth)
      .send({ ...newTeacher, ...override })
      .expect(422);
    expect(res.body).toEqual({ message });
  });
});

describe('PATCH /api/admin/users/:id', () => {
  let admin: TestAccount;
  let target: TestAccount;
  beforeEach(async () => {
    admin = await createAdmin({ displayName: 'Campus Admin' });
    target = await createStudent({
      displayName: 'Sarra Mansouri',
      email: 'sarra.mansouri@campus.test',
      studentId: '221JMT0101',
    });
  });

  test('changes the name, email and ENT ID', async () => {
    const res = await patch(admin.auth, target.user.id, {
      displayName: 'Sarra Ben Ali',
      email: 'Sarra.BenAli@campus.test',
      studentId: '221jmt0199',
    }).expect(200);

    expect(res.body).toEqual({
      id: target.user.id,
      email: 'sarra.benali@campus.test',
      studentId: '221JMT0199',
      displayName: 'Sarra Ben Ali',
      role: 'student',
      isEmailVerified: true,
      createdAt: target.user.createdAt.toISOString(),
    });
    const entry = await AuditLogModel.findOne().lean();
    expect(entry).toMatchObject({
      action: 'user.update',
      summary: 'Updated Sarra Mansouri (name, email, ENT ID)',
      targetId: target.user.id,
      metadata: { changes: ['displayName', 'email', 'studentId'] },
    });
  });

  test('removes the ENT ID with null (several accounts can have none)', async () => {
    await createStudent();
    const res = await patch(admin.auth, target.user.id, { studentId: null }).expect(200);
    expect(res.body.studentId).toBeNull();
    const stored = await UserModel.findById(target.user.id).lean();
    expect(stored).not.toHaveProperty('studentId');

    await patch(admin.auth, target.user.id, { studentId: '221JMT0101' }).expect(200);
    await patch(admin.auth, target.user.id, { studentId: '' }).expect(200);
    expect((await UserModel.findById(target.user.id))?.studentId).toBeUndefined();
  });

  test('changes the role and the verified flag', async () => {
    const res = await patch(admin.auth, target.user.id, { role: 'teacher' }).expect(200);
    expect(res.body.role).toBe('teacher');
    const unverified = await patch(admin.auth, target.user.id, { isEmailVerified: false }).expect(200);
    expect(unverified.body.isEmailVerified).toBe(false);

    const entries = await AuditLogModel.find().sort({ createdAt: 1, _id: 1 }).lean();
    expect(entries.map((e) => [e.summary, e.metadata])).toEqual([
      [
        'Changed the role of Sarra Mansouri to Teacher',
        { changes: ['role'], role: { from: 'student', to: 'teacher' } },
      ],
      ['Updated Sarra Mansouri (email verification)', { changes: ['isEmailVerified'] }],
    ]);
  });

  test('a new password works at once and signs the user out on every device', async () => {
    const created = await request(app)
      .post('/api/admin/users')
      .set(admin.auth)
      .send({ displayName: 'Omar', email: 'omar@campus.test', password: 'first-password' })
      .expect(201);
    const phone = await login('omar@campus.test', 'first-password').expect(200);
    const laptop = await login('omar@campus.test', 'first-password').expect(200);

    await patch(admin.auth, created.body.id as string, { password: 'second-password' }).expect(200);

    for (const session of [phone, laptop]) {
      await request(app)
        .post('/api/auth/refresh')
        .send({ refreshToken: session.body.refreshToken as string })
        .expect(401);
    }
    await login('omar@campus.test', 'first-password').expect(401);
    await login('omar@campus.test', 'second-password').expect(200);

    const entry = await AuditLogModel.findOne({ targetId: created.body.id as string }).where({
      action: 'user.update',
    });
    expect(entry?.summary).toBe('Updated Omar (password)');
    expect(JSON.stringify(entry)).not.toContain('second-password');
  });

  test('sending the current values changes nothing and records nothing', async () => {
    const res = await patch(admin.auth, target.user.id, {
      displayName: 'Sarra Mansouri',
      email: 'SARRA.MANSOURI@campus.test',
      studentId: '221jmt0101',
      role: 'student',
      isEmailVerified: true,
    }).expect(200);
    expect(res.body).toMatchObject({ displayName: 'Sarra Mansouri', role: 'student' });
    expect(await AuditLogModel.countDocuments()).toBe(0);
    expect(await accountNotificationsOf(target.auth)).toEqual([]);
  });

  test.each([{}, { unknown: 'field' }, { displayName: undefined }])(
    'answers 422 "There\'s nothing to save." for %j',
    async (body) => {
      await patch(admin.auth, target.user.id, body).expect(422, {
        message: "There's nothing to save.",
      });
    },
  );

  test.each([
    [{ displayName: ' ' }, 'Enter a name'],
    [{ email: 'nope' }, 'Enter a valid email'],
    [{ password: 'short' }, 'Use at least 8 characters'],
    [{ studentId: 'A' }, 'ENT ID: 3 to 20 letters or digits'],
    [{ role: 'root' }, 'Role: not recognised (student, teacher, admin or alumni)'],
    [{ isEmailVerified: 'yes' }, 'isEmailVerified must be true or false'],
  ])('answers 422 for %j', async (body, message) => {
    await patch(admin.auth, target.user.id, body).expect(422, { message });
  });

  test('answers 404 for an unknown or invalid id', async () => {
    const notFound = { message: 'User not found.' };
    await patch(admin.auth, new Types.ObjectId().toHexString(), { role: 'teacher' }).expect(
      404,
      notFound,
    );
    await patch(admin.auth, 'nope', { role: 'teacher' }).expect(404, notFound);
  });

  test('answers 409 for an email or ENT ID of another account', async () => {
    await createStudent({ email: 'taken@campus.test', studentId: '221JMT0555' });
    await patch(admin.auth, target.user.id, { email: 'Taken@campus.test' }).expect(409, {
      message: 'An account with this email already exists.',
    });
    await patch(admin.auth, target.user.id, { studentId: '221jmt0555' }).expect(409, {
      message: 'This ENT ID is already in use.',
    });
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });

  describe('on the admin\'s own account', () => {
    test.each([
      { role: 'student' },
      { password: 'a-new-password' },
      { isEmailVerified: false },
      { displayName: 'Boss', role: 'teacher' },
    ])('refuses %j with 400', async (body) => {
      await patch(admin.auth, admin.user.id, body).expect(400, {
        message: 'On your own account, you can only change your name, email and ENT ID.',
      });
      expect((await UserModel.findById(admin.user.id))?.role).toBe('admin');
    });

    test('accepts the name, email and ENT ID, and the unchanged role', async () => {
      const res = await patch(admin.auth, admin.user.id, {
        displayName: 'Chief Admin',
        email: 'chief@campus.test',
        studentId: 'STAFF001',
        role: 'admin',
      }).expect(200);
      expect(res.body).toMatchObject({
        displayName: 'Chief Admin',
        email: 'chief@campus.test',
        studentId: 'STAFF001',
        role: 'admin',
      });
      // Never notified about their own changes.
      expect(await accountNotificationsOf(admin.auth)).toEqual([]);
    });
  });

  describe('account notifications', () => {
    test('tell the user their new role', async () => {
      await patch(admin.auth, target.user.id, { role: 'teacher' }).expect(200);

      const [notification, ...others] = await notificationsOf(target.auth);
      expect(others).toEqual([]);
      expect(notification).toEqual({
        id: expect.any(String),
        category: 'account',
        label: 'Account',
        title: 'Your account was updated',
        body: 'Your role is now: **Teacher**.',
        receivedAt: expect.any(String),
        isRead: false,
        isUrgent: false,
        attachment: null,
        link: { destination: 'profile', id: null },
      });
    });

    test('list every change, urgent when the password changed', async () => {
      await patch(admin.auth, target.user.id, {
        role: 'alumni',
        email: 'sarra@alumni.test',
        password: 'brand-new-password',
        displayName: 'Sarra M.',
      }).expect(200);

      const [notification] = await accountNotificationsOf(target.auth);
      expect(notification.body).toBe(
        'Your role is now: **Alumni**.\n' +
          'Your sign-in email is now **sarra@alumni.test**.\n' +
          'An administrator changed your password: sign in with the new one.',
      );
      expect(notification.isUrgent).toBe(true);
    });

    test('are not sent for the name, ENT ID or verified flag', async () => {
      await patch(admin.auth, target.user.id, {
        displayName: 'Sarra M.',
        studentId: null,
        isEmailVerified: false,
      }).expect(200);
      expect(await accountNotificationsOf(target.auth)).toEqual([]);
    });
  });
});

describe('sign-up notifications', () => {
  test('every admin hears about a new account, nobody else', async () => {
    const first = await createAdmin();
    const second = await createAdmin();
    const student = await createStudent();

    const res = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Yasmine Haddad', email: 'Yasmine@campus.test', password: 'password123' })
      .expect(201);
    const newId = res.body.user.id as string;

    for (const admin of [first, second]) {
      const items = await notificationsOf(admin.auth);
      expect(items).toEqual([
        {
          id: expect.any(String),
          category: 'account',
          label: 'Account',
          title: 'New account: Yasmine Haddad',
          body: '**yasmine@campus.test** just signed up.',
          receivedAt: expect.any(String),
          isRead: false,
          isUrgent: false,
          attachment: null,
          link: { destination: 'adminUsers', id: newId },
        },
      ]);
    }
    expect(await accountNotificationsOf(student.auth)).toEqual([]);
  });

  test('a notification problem never breaks the sign-up', async () => {
    await createAdmin();
    const spy = jest.spyOn(NotificationModel, 'insertMany').mockRejectedValueOnce(new Error('down'));
    const log = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    try {
      await request(app)
        .post('/api/auth/register')
        .send({ displayName: 'Eve', email: 'eve@campus.test', password: 'password123' })
        .expect(201);
      expect(log).toHaveBeenCalled();
    } finally {
      spy.mockRestore();
      log.mockRestore();
    }
  });

  test('accounts created by an admin don\'t notify the admins', async () => {
    const admin = await createAdmin();
    await request(app)
      .post('/api/admin/users')
      .set(admin.auth)
      .send({ displayName: 'Omar', email: 'omar@campus.test', password: 'password123' })
      .expect(201);
    expect(await accountNotificationsOf(admin.auth)).toEqual([]);
  });
});

describe('DELETE /api/admin/users/:id', () => {
  const MINUTE = 60 * 1000;

  function ride(id: string, driverId: Types.ObjectId | null, seats: object[]) {
    const departure = new Date(Date.now() + 60 * MINUTE);
    return {
      _id: id,
      code: id.toUpperCase(),
      driverId,
      pickup: 'Lac 2',
      pickupTag: 'Lac 2',
      dropoff: 'ESPRIT Ghazela',
      dropoffTag: 'ESPRIT',
      departure,
      arrival: new Date(departure.getTime() + 30 * MINUTE),
      distanceKm: 12,
      pricePerSeat: 2,
      driver: {
        name: 'Driver',
        rating: 0,
        profile: 'ESPRIT student',
        ridesCompleted: 0,
        carModel: 'Polo',
        carColor: 'Blue',
        plate: '231 TN 1187',
      },
      seats,
    };
  }

  /** One row in every collection that belongs to [userId]. */
  async function addAccountData(userId: Types.ObjectId, tag: string) {
    await RefreshTokenModel.create({
      userId,
      tokenHash: `hash-${tag}`,
      expiresAt: new Date(Date.now() + 60 * MINUTE),
    });
    await NotificationModel.create({
      userId,
      key: `n-${tag}`,
      category: 'academic',
      label: 'Grades',
      title: 'A grade',
      body: 'A grade.',
    });
    await CourseAttendanceModel.create({ userId, courseId: 'genie-logiciel', present: true });
    await AssignmentSubmissionModel.create({
      userId,
      assignmentId: 'gl-lab-3',
      repoUrl: 'https://github.com/x/y',
    });
    await JobApplicationModel.create({ userId, jobId: 'instadeep-ml' });
    await IdeaVoteModel.create({ userId, ideaId: 'post-3' });
    await LostItemRequestModel.create({ userId, itemId: 'lf-409', proof: 'Purple sticker' });
    await TranscriptModel.create({ userId, semesters: [] });
    await StudentProfileModel.create({ userId });
    await ForumPostModel.create({
      _id: `post-${tag}`,
      authorId: userId,
      authorName: `Author ${tag}`,
      authorInfo: '4A',
      category: 'idea',
      tag: 'Proposition',
      body: 'An idea for the campus.',
      postedAt: new Date(),
    });
    await LostItemModel.create({
      _id: `lf-${tag}`,
      reporterId: userId,
      kind: 'lost',
      title: 'Keys',
      category: 'keys',
      zone: 'Parking',
      location: 'Parking B',
      place: 'parking',
      reporterName: `Reporter ${tag}`,
      reportedAt: new Date(),
    });
  }

  /** How many rows [userId] has in each user-keyed collection. */
  const rowsOf = (userId: Types.ObjectId) =>
    Promise.all([
      RefreshTokenModel.countDocuments({ userId }),
      NotificationModel.countDocuments({ userId }),
      CourseAttendanceModel.countDocuments({ userId }),
      AssignmentSubmissionModel.countDocuments({ userId }),
      JobApplicationModel.countDocuments({ userId }),
      IdeaVoteModel.countDocuments({ userId }),
      LostItemRequestModel.countDocuments({ userId }),
      TranscriptModel.countDocuments({ userId }),
      StudentProfileModel.countDocuments({ userId }),
    ]);

  test('deletes the account and its data, frees its seats, keeps its posts', async () => {
    const admin = await createAdmin();
    const target = await createStudent({ displayName: 'Sarra Mansouri', email: 'sarra@campus.test' });
    const other = await createStudent();
    await addAccountData(target.user._id, 'target');
    await addAccountData(other.user._id, 'other');
    await RideModel.create(
      ride('es-5001', target.user._id, [
        { seatId: 's1', status: 'driver' },
        { seatId: 's2', status: 'booked', passengerId: other.user._id, passengerName: 'Other' },
      ]),
    );
    await RideModel.create(
      ride('es-5002', other.user._id, [
        { seatId: 's1', status: 'driver' },
        { seatId: 's2', status: 'booked', passengerId: target.user._id, passengerName: 'Sarra M.' },
        { seatId: 's3', status: 'booked', passengerId: admin.user._id, passengerName: 'Admin' },
        { seatId: 's4', status: 'booked', passengerId: target.user._id, passengerName: 'Sarra M.' },
      ]),
    );

    await request(app).delete(`/api/admin/users/${target.user.id}`).set(admin.auth).expect(204);

    expect(await UserModel.exists({ _id: target.user._id })).toBeNull();
    expect(await rowsOf(target.user._id)).toEqual([0, 0, 0, 0, 0, 0, 0, 0, 0]);
    expect(await rowsOf(other.user._id)).toEqual([1, 1, 1, 1, 1, 1, 1, 1, 1]);
    expect(await RideModel.exists({ _id: 'es-5001' })).toBeNull();
    const kept = await RideModel.findById('es-5002').lean();
    expect(
      kept?.seats.map((s) => [s.seatId, s.status, s.passengerId?.toString() ?? null, s.passengerName]),
    ).toEqual([
      ['s1', 'driver', null, null],
      ['s2', 'free', null, null],
      ['s3', 'booked', admin.user.id, 'Admin'],
      ['s4', 'free', null, null],
    ]);
    const post = await ForumPostModel.findById('post-target').lean();
    expect(post).toMatchObject({ authorId: null, authorName: 'Author target' });
    expect((await ForumPostModel.findById('post-other').lean())?.authorId).toEqual(other.user._id);
    const item = await LostItemModel.findById('lf-target').lean();
    expect(item).toMatchObject({ reporterId: null, reporterName: 'Reporter target' });
    expect((await LostItemModel.findById('lf-other').lean())?.reporterId).toEqual(other.user._id);

    const entry = await AuditLogModel.findOne().lean();
    expect(entry).toMatchObject({
      action: 'user.delete',
      summary: 'Deleted the account of Sarra Mansouri (sarra@campus.test)',
      targetId: target.user.id,
      metadata: { email: 'sarra@campus.test', role: 'student' },
    });
  });

  test('the deleted user\'s token stops working', async () => {
    const admin = await createAdmin();
    const target = await createStudent();
    await request(app).delete(`/api/admin/users/${target.user.id}`).set(admin.auth).expect(204);
    await request(app).get('/api/users/me').set(target.auth).expect(401);
  });

  test('refuses the admin\'s own account', async () => {
    const admin = await createAdmin();
    await request(app)
      .delete(`/api/admin/users/${admin.user.id}`)
      .set(admin.auth)
      .expect(400, { message: "You can't delete your own account." });
    // Even written in capitals.
    await request(app)
      .delete(`/api/admin/users/${admin.user.id.toUpperCase()}`)
      .set(admin.auth)
      .expect(400);
    expect(await UserModel.exists({ _id: admin.user._id })).not.toBeNull();
  });

  test('an admin can delete another admin', async () => {
    const admin = await createAdmin();
    const other = await createAdmin();
    await request(app).delete(`/api/admin/users/${other.user.id}`).set(admin.auth).expect(204);
    await request(app).get('/api/admin/users').set(other.auth).expect(401);
  });

  test('answers 404 for an unknown or invalid id', async () => {
    const admin = await createAdmin();
    const notFound = { message: 'User not found.' };
    await request(app)
      .delete(`/api/admin/users/${new Types.ObjectId().toHexString()}`)
      .set(admin.auth)
      .expect(404, notFound);
    await request(app).delete('/api/admin/users/nope').set(admin.auth).expect(404, notFound);
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });
});
