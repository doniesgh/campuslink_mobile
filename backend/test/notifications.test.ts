import type { Types } from 'mongoose';
import request from 'supertest';

import { createApp } from '../src/app';
import { NotificationModel } from '../src/modules/notifications/notification.model';
import { seedNotifications } from '../src/modules/notifications/notifications.seed';
import { UserModel } from '../src/modules/users/user.model';
import { clearTestDb, closeTestDb, connectTestDb, createStudent } from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

interface NotificationBody {
  id: string;
  category: string;
  label: string;
  title: string;
  body: string;
  receivedAt: string;
  isRead: boolean;
  isUrgent: boolean;
  attachment: Record<string, unknown> | null;
  link: { destination: string; id: string | null } | null;
}

/** Stores a notification for [userId] directly in the database. */
async function addNotification(
  userId: Types.ObjectId,
  key: string,
  overrides: { receivedAt?: Date; isRead?: boolean } = {},
) {
  return NotificationModel.create({
    userId,
    key,
    category: 'academic',
    label: 'Grades',
    title: `Notification ${key}`,
    body: 'A **new** grade is out.',
    receivedAt: overrides.receivedAt ?? new Date(),
    isRead: overrides.isRead ?? false,
  });
}

async function list(auth: { Authorization: string }): Promise<NotificationBody[]> {
  const res = await request(app).get('/api/notifications').set(auth).expect(200);
  return res.body as NotificationBody[];
}

const unread = (items: NotificationBody[]) => items.filter((n) => !n.isRead).map((n) => n.id);

describe('authentication', () => {
  test.each([
    ['get', '/api/notifications'],
    ['post', '/api/notifications/read-all'],
    ['post', '/api/notifications/some-id/read'],
  ] as const)('%s %s answers 401 without a token', async (method, path) => {
    const res = await request(app)[method](path).expect(401);
    expect(res.body).toEqual({ message: 'Invalid credentials or expired session.' });
  });

  test('answers 401 with an invalid token', async () => {
    await request(app)
      .get('/api/notifications')
      .set({ Authorization: 'Bearer not-a-token' })
      .expect(401);
  });
});

describe('GET /api/notifications', () => {
  test('gives a brand-new student a single unread welcome notification, once', async () => {
    const { auth, user } = await createStudent();

    const first = await list(auth);
    expect(first).toEqual([
      {
        id: 'welcome',
        category: 'community',
        label: 'CampusPulse',
        title: 'Welcome to CampusPulse',
        body: expect.stringContaining('**room changes**'),
        receivedAt: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/),
        isRead: false,
        isUrgent: false,
        attachment: null,
        link: null,
      },
    ]);
    if (process.env.PRINT_NOTIFICATIONS_JSON) console.log(JSON.stringify(first, null, 2));

    // Still one after reading it, and after more visits.
    await request(app).post('/api/notifications/welcome/read').set(auth).expect(204);
    const again = await list(auth);
    expect(again).toHaveLength(1);
    expect(again[0]?.isRead).toBe(true);
    expect(await NotificationModel.countDocuments({ userId: user._id })).toBe(1);
  });

  test('creates only one welcome notification when the first requests arrive together', async () => {
    const { auth, user } = await createStudent();
    const results = await Promise.all([list(auth), list(auth), list(auth)]);
    for (const items of results) expect(items.map((n) => n.id)).toEqual(['welcome']);
    expect(await NotificationModel.countDocuments({ userId: user._id })).toBe(1);
  });

  test('does not welcome a student who already has notifications', async () => {
    const { auth, user } = await createStudent();
    await addNotification(user._id, 'grade-1');
    expect((await list(auth)).map((n) => n.id)).toEqual(['grade-1']);
  });

  test("returns only the caller's notifications, newest first", async () => {
    const me = await createStudent();
    const other = await createStudent();
    const at = (iso: string) => ({ receivedAt: new Date(iso) });
    // Inserted out of order on purpose.
    await addNotification(me.user._id, 'middle', at('2026-11-04T08:00:00.000Z'));
    await addNotification(me.user._id, 'oldest', at('2026-11-01T08:00:00.000Z'));
    await addNotification(me.user._id, 'newest', at('2026-11-05T09:15:00.000Z'));
    await addNotification(other.user._id, 'theirs', at('2026-11-06T08:00:00.000Z'));

    const items = await list(me.auth);
    expect(items.map((n) => n.id)).toEqual(['newest', 'middle', 'oldest']);
    expect(items[0]?.receivedAt).toBe('2026-11-05T09:15:00.000Z');
    expect(items.map((n) => n.id)).not.toContain('theirs');
  });

  test('answers 401 when the account no longer exists', async () => {
    const { auth, user } = await createStudent();
    await UserModel.deleteOne({ _id: user._id });
    await request(app).get('/api/notifications').set(auth).expect(401);
    expect(await NotificationModel.countDocuments({})).toBe(0);
  });
});

describe('POST /api/notifications/:id/read', () => {
  test('marks the notification as read, and again is fine', async () => {
    const { auth, user } = await createStudent();
    await addNotification(user._id, 'a');
    await addNotification(user._id, 'b');

    const res = await request(app).post('/api/notifications/a/read').set(auth).expect(204);
    expect(res.text).toBe('');
    expect(unread(await list(auth))).toEqual(['b']);

    await request(app).post('/api/notifications/a/read').set(auth).expect(204);
    expect(unread(await list(auth))).toEqual(['b']);
  });

  test('answers 404 for a notification that does not exist', async () => {
    const { auth, user } = await createStudent();
    await addNotification(user._id, 'a');
    const res = await request(app).post('/api/notifications/nope/read').set(auth).expect(404);
    expect(res.body).toEqual({ message: 'Notification not found.' });
  });

  test("answers 404 for another student's notification and leaves it unread", async () => {
    const owner = await createStudent();
    const intruder = await createStudent();
    await addNotification(owner.user._id, 'private');
    await addNotification(intruder.user._id, 'mine');

    const res = await request(app)
      .post('/api/notifications/private/read')
      .set(intruder.auth)
      .expect(404);
    expect(res.body).toEqual({ message: 'Notification not found.' });
    expect(unread(await list(owner.auth))).toEqual(['private']);
  });

  test('two students can have the same notification id independently', async () => {
    const a = await createStudent();
    const b = await createStudent();
    await addNotification(a.user._id, 'room-change-gl');
    await addNotification(b.user._id, 'room-change-gl');

    await request(app).post('/api/notifications/room-change-gl/read').set(a.auth).expect(204);

    expect(unread(await list(a.auth))).toEqual([]);
    expect(unread(await list(b.auth))).toEqual(['room-change-gl']);
  });
});

describe('POST /api/notifications/read-all', () => {
  test("marks all of the caller's notifications as read, and only theirs", async () => {
    const me = await createStudent();
    const other = await createStudent();
    await addNotification(me.user._id, 'a');
    await addNotification(me.user._id, 'b', { isRead: true });
    await addNotification(me.user._id, 'c');
    await addNotification(other.user._id, 'x');

    const res = await request(app).post('/api/notifications/read-all').set(me.auth).expect(204);
    expect(res.text).toBe('');

    const mine = await list(me.auth);
    expect(mine).toHaveLength(3);
    expect(unread(mine)).toEqual([]);
    expect(unread(await list(other.auth))).toEqual(['x']);
  });

  test('is fine with nothing to mark', async () => {
    const { auth } = await createStudent();
    await request(app).post('/api/notifications/read-all').set(auth).expect(204);
    await request(app).post('/api/notifications/read-all').set(auth).expect(204);
  });
});

describe('seedNotifications', () => {
  // 10:30 in Tunis (UTC+1), the time used by the app's notification tests.
  const now = new Date('2026-11-05T09:30:00.000Z');

  test('gives the demo student the 9 notifications of the app mock, 3 unread', async () => {
    const demo = await createStudent({ studentId: '211JMT0428' });
    await seedNotifications(demo.user._id, now);

    const items = await list(demo.auth);
    if (process.env.PRINT_NOTIFICATIONS_JSON) console.log(JSON.stringify(items, null, 2));

    expect(items.map((n) => n.id)).toEqual([
      'room-change-gl',
      'ride-confirmed-es-4091',
      'exam-timetable-s8',
      'grade-bdd',
      'lost-found-492',
      'forum-reply',
      'job-instadeep-viewed',
      'course-material-gl',
      'carpool-digest',
    ]);
    expect(unread(items)).toEqual(['room-change-gl', 'ride-confirmed-es-4091', 'job-instadeep-viewed']);
    expect(items.filter((n) => n.isUrgent).map((n) => n.id)).toEqual([
      'room-change-gl',
      'lost-found-492',
    ]);

    // Times relative to the seed time, sent as ISO UTC instants.
    expect(items.map((n) => n.receivedAt)).toEqual([
      '2026-11-05T09:15:00.000Z', // 15 min ago
      '2026-11-05T08:30:00.000Z', // 1 h ago
      '2026-11-04T13:30:00.000Z', // yesterday 14:30 in Tunis
      '2026-11-04T08:10:00.000Z', // yesterday 09:10 in Tunis
      '2026-11-03T06:30:00.000Z', // 2 days 3 h ago
      '2026-11-03T03:30:00.000Z', // 2 days 6 h ago
      '2026-11-02T07:30:00.000Z', // 3 days 2 h ago
      '2026-11-01T08:30:00.000Z', // 4 days 1 h ago
      '2026-10-31T05:30:00.000Z', // 5 days 4 h ago
    ]);

    const byId = new Map(items.map((n) => [n.id, n]));
    expect(byId.get('room-change-gl')).toEqual({
      id: 'room-change-gl',
      category: 'academic',
      label: 'Urgent Academic',
      title: 'Room Change: Génie Logiciel',
      body:
        'Lecture today at **10:15** moved from ~~Amphi 3B~~ to ' +
        '==Grand Amphi C== due to faculty seminar.',
      receivedAt: '2026-11-05T09:15:00.000Z',
      isRead: false,
      isUrgent: true,
      attachment: { type: 'place', place: 'Grand Amphi C, Pavillon Principal' },
      link: { destination: 'timetable', id: null },
    });
    expect(byId.get('ride-confirmed-es-4091')?.attachment).toEqual({
      type: 'ride',
      driverName: 'Sarra K.',
      carLabel: 'Clio 4 · Blanc glacier',
      isDriverVerified: true,
    });
    expect(byId.get('exam-timetable-s8')?.attachment).toEqual({ type: 'schedule' });
    expect(byId.get('lost-found-492')?.attachment).toEqual({
      type: 'pickup',
      availability: 'Available for pickup until 17h00',
      ticket: '492',
    });
    expect(byId.get('grade-bdd')?.attachment).toBeNull();

    // Links point at ids and tabs that exist in the other modules' seeds.
    expect(items.map((n) => n.link)).toEqual([
      { destination: 'timetable', id: null },
      { destination: 'ride', id: 'es-4091' },
      { destination: 'timetable', id: null },
      { destination: 'grades', id: null },
      { destination: 'forum', id: null },
      { destination: 'forum', id: null },
      { destination: 'job', id: 'instadeep-ml' },
      { destination: 'courses', id: null },
      { destination: 'forum', id: null },
    ]);
    expect(new Set(items.map((n) => n.category))).toEqual(
      new Set(['academic', 'covoiturage', 'lostFound', 'career', 'community']),
    );
  });

  test('is idempotent: running it again resets the feed', async () => {
    const demo = await createStudent();
    const other = await createStudent();
    await addNotification(other.user._id, 'untouched');

    await seedNotifications(demo.user._id, now);
    await request(app).post('/api/notifications/read-all').set(demo.auth).expect(204);
    await seedNotifications(demo.user._id);

    const items = await list(demo.auth);
    expect(items).toHaveLength(9);
    expect(unread(items)).toHaveLength(3);
    // Re-running moves the times back to "now".
    expect(Date.now() - Date.parse(items[0]?.receivedAt ?? '')).toBeLessThan(16 * 60 * 1000);
    expect(unread(await list(other.auth))).toEqual(['untouched']);
  });
});
