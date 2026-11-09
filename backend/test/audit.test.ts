import request from 'supertest';

import { createApp } from '../src/app';
import { AuditLogModel } from '../src/modules/admin/audit-log.model';
import { recordAudit } from '../src/modules/admin/audit.service';
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

type Auth = { Authorization: string };

interface AuditEntryBody {
  id: string;
  action: string;
  summary: string;
  actor: { id: string; displayName: string; email: string };
  targetId: string | null;
  metadata: Record<string, unknown>;
  ip: string | null;
  createdAt: string;
}

interface AuditPageBody {
  items: AuditEntryBody[];
  total: number;
  page: number;
  limit: number;
}

const listAudit = async (auth: Auth, query: Record<string, string | number> = {}) =>
  (await request(app).get('/api/admin/audit').query(query).set(auth).expect(200))
    .body as AuditPageBody;

const actionsOf = (page: AuditPageBody) => page.items.map((e) => e.action);

let admin: TestAccount;
beforeEach(async () => {
  admin = await createAdmin({ displayName: 'Campus Admin', email: 'admin@campus.test' });
});

/** One action of each kind, in this order: create, update, import, delete. */
async function doOneOfEach(): Promise<string> {
  const created = await request(app)
    .post('/api/admin/users')
    .set(admin.auth)
    .send({
      displayName: 'Amira Ben Salah',
      email: 'amira.bensalah@campus.test',
      password: 'password123',
      role: 'teacher',
    })
    .expect(201);
  const id = created.body.id as string;
  await request(app)
    .patch(`/api/admin/users/${id}`)
    .set(admin.auth)
    .send({ role: 'admin' })
    .expect(200);
  await request(app)
    .post('/api/admin/users/import')
    .set(admin.auth)
    .send({
      dryRun: false,
      users: [{ row: 2, displayName: 'Omar', email: 'omar@import.test', password: 'password123' }],
    })
    .expect(201);
  await request(app).delete(`/api/admin/users/${id}`).set(admin.auth).expect(204);
  return id;
}

describe('GET /api/admin/audit', () => {
  test('lists every admin action, newest first', async () => {
    const targetId = await doOneOfEach();

    const page = await listAudit(admin.auth);

    expect(page).toMatchObject({ total: 4, page: 1, limit: 30 });
    const actor = { id: admin.user.id, displayName: 'Campus Admin', email: 'admin@campus.test' };
    expect(page.items).toEqual([
      {
        id: expect.any(String),
        action: 'user.delete',
        summary: 'Deleted the account of Amira Ben Salah (amira.bensalah@campus.test)',
        actor,
        targetId,
        metadata: { email: 'amira.bensalah@campus.test', role: 'admin' },
        ip: '127.0.0.1',
        createdAt: expect.any(String),
      },
      {
        id: expect.any(String),
        action: 'user.import',
        summary: 'Imported 1 account',
        actor,
        targetId: null,
        metadata: { count: 1, emails: ['omar@import.test'] },
        ip: '127.0.0.1',
        createdAt: expect.any(String),
      },
      {
        id: expect.any(String),
        action: 'user.update',
        summary: 'Changed the role of Amira Ben Salah to Admin',
        actor,
        targetId,
        metadata: { changes: ['role'], role: { from: 'teacher', to: 'admin' } },
        ip: '127.0.0.1',
        createdAt: expect.any(String),
      },
      {
        id: expect.any(String),
        action: 'user.create',
        summary: 'Created the teacher account amira.bensalah@campus.test',
        actor,
        targetId,
        metadata: { role: 'teacher' },
        ip: '127.0.0.1',
        createdAt: expect.any(String),
      },
    ]);
    const times = page.items.map((e) => e.createdAt);
    expect([...times].sort().reverse()).toEqual(times);
    expect(new Date(times[0]).toISOString()).toBe(times[0]);
  });

  test('filters on an exact action or a prefix with *', async () => {
    await doOneOfEach();

    expect(actionsOf(await listAudit(admin.auth, { action: 'user.update' }))).toEqual([
      'user.update',
    ]);
    const all = await listAudit(admin.auth, { action: 'user.*' });
    expect(actionsOf(all)).toEqual(['user.delete', 'user.import', 'user.update', 'user.create']);
    expect(all.total).toBe(4);
    expect((await listAudit(admin.auth, { action: '*' })).total).toBe(4);
    expect((await listAudit(admin.auth, { action: 'user' })).total).toBe(0);
    expect((await listAudit(admin.auth, { action: 'user.' })).total).toBe(0);
    expect((await listAudit(admin.auth, { action: 'job.*' })).total).toBe(0);
    // "." is not a wildcard in the prefix.
    expect((await listAudit(admin.auth, { action: 'userx*' })).total).toBe(0);
    expect((await listAudit(admin.auth, { action: 'user?*' })).total).toBe(0);
  });

  test('pages through the entries', async () => {
    await doOneOfEach();

    const second = await listAudit(admin.auth, { page: 2, limit: 3 });
    expect(actionsOf(second)).toEqual(['user.create']);
    expect(second).toMatchObject({ total: 4, page: 2, limit: 3 });
  });

  test('keeps the actor as they were, even once deleted', async () => {
    const other = await createAdmin({ displayName: 'Old Admin', email: 'old@campus.test' });
    const { user: student } = await createStudent();
    await request(app)
      .patch(`/api/admin/users/${student.id}`)
      .set(other.auth)
      .send({ displayName: 'Renamed' })
      .expect(200);
    await request(app).delete(`/api/admin/users/${other.user.id}`).set(admin.auth).expect(204);

    const page = await listAudit(admin.auth, { action: 'user.update' });
    expect(page.items[0].actor).toEqual({
      id: other.user.id,
      displayName: 'Old Admin',
      email: 'old@campus.test',
    });
  });

  test('never stores a password', async () => {
    const { user } = await createStudent();
    await request(app)
      .patch(`/api/admin/users/${user.id}`)
      .set(admin.auth)
      .send({ password: 'super-secret-pass', displayName: 'Renamed' })
      .expect(200);

    const page = await listAudit(admin.auth);
    expect(page.items[0]).toMatchObject({
      summary: `Updated ${user.displayName} (name, password)`,
      metadata: { changes: ['displayName', 'password'] },
    });
    const stored = JSON.stringify(await AuditLogModel.find().lean());
    expect(stored).not.toContain('super-secret-pass');
  });

  test('sends {} for an entry without metadata', async () => {
    await recordAudit({
      actorId: admin.user.id,
      action: 'user.import',
      summary: 'Imported 0 accounts',
      ip: null,
    });
    const page = await listAudit(admin.auth);
    expect(page.items[0]).toMatchObject({ metadata: {}, targetId: null, ip: null });
  });

  test.each([
    [{ page: 0 }, 'Pass a page number of 1 or more'],
    [{ limit: 101 }, 'Pass a limit between 1 and 100'],
    [{ limit: 'ten' }, 'Pass a limit between 1 and 100'],
    [{ action: 'x'.repeat(61) }, 'The action filter is too long'],
  ] as const)('answers 422 for %j', async (query, message) => {
    const res = await request(app).get('/api/admin/audit').query(query).set(admin.auth).expect(422);
    expect(res.body).toEqual({ message });
  });
});

describe('GET /api/admin/audit/actions', () => {
  test('lists the actions recorded so far, once each, alphabetically', async () => {
    await request(app).get('/api/admin/audit/actions').set(admin.auth).expect(200, []);

    await doOneOfEach();
    await request(app)
      .patch(`/api/admin/users/${admin.user.id}`)
      .set(admin.auth)
      .send({ displayName: 'Chief Admin' })
      .expect(200);

    await request(app)
      .get('/api/admin/audit/actions')
      .set(admin.auth)
      .expect(200, ['user.create', 'user.delete', 'user.import', 'user.update']);
  });
});
