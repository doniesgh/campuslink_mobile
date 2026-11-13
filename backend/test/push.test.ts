import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

import type { Types } from 'mongoose';
import request from 'supertest';

import { createApp } from '../src/app';
import { revokeAllSessions } from '../src/modules/auth/auth.service';
import { NotificationModel } from '../src/modules/notifications/notification.model';
import { createFcmSender, initPush } from '../src/modules/push/fcm';
import { PushDeviceModel } from '../src/modules/push/push-device.model';
import { MAX_DEVICES_PER_USER } from '../src/modules/push/push-devices.service';
import {
  isPushOn,
  plainText,
  pushNotifications,
  setPushSender,
  type PushMessage,
} from '../src/modules/push/push.service';
import {
  captureMail,
  capturePush,
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  type TestAccount,
  validationError,
} from './helpers';

const app = createApp();
const mail = captureMail();
const push = capturePush();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(async () => {
  await clearTestDb();
  push.reset();
  mail.emails.length = 0;
  mail.resets.length = 0;
});
// No background push may leak into the next test.
afterEach(() => push.settle());

type Auth = { Authorization: string };

const NOT_REGISTERED = 'messaging/registration-token-not-registered';

const registerDevice = (auth: Auth, body: object) =>
  request(app).put('/api/push/devices').set(auth).send(body);

const unregisterDevice = (auth: Auth, body: object) =>
  request(app).delete('/api/push/devices').set(auth).send(body);

/** [userId]'s devices, least recently seen first. */
const devicesOf = (userId: Types.ObjectId) =>
  PushDeviceModel.find({ userId }).sort({ lastSeenAt: 1, _id: 1 }).lean();

const tokensOf = async (userId: Types.ObjectId) => (await devicesOf(userId)).map((d) => d.token);

/** Registers [tokens] for [account] through the API. */
async function givePhones(account: TestAccount, ...tokens: string[]): Promise<void> {
  for (const token of tokens) {
    await registerDevice(account.auth, { token, platform: 'android' }).expect(204);
  }
}

const sentTokens = () => push.messages.map((m) => m.token).sort();

describe('PUT /api/push/devices', () => {
  test('registers the phone of the signed-in user', async () => {
    const student = await createStudent();
    const before = Date.now();

    await registerDevice(student.auth, { token: '  fcm-token-1  ', platform: 'ios' }).expect(204, '');

    const [device] = await devicesOf(student.user._id);
    expect(device).toMatchObject({ userId: student.user._id, token: 'fcm-token-1', platform: 'ios' });
    expect(device.lastSeenAt.getTime()).toBeGreaterThanOrEqual(before);
  });

  test('registering the same token again updates it instead of adding a device', async () => {
    const student = await createStudent();
    await registerDevice(student.auth, { token: 'fcm-token-1', platform: 'android' }).expect(204);
    const longAgo = new Date('2026-01-01T00:00:00Z');
    await PushDeviceModel.updateOne({ token: 'fcm-token-1' }, { $set: { lastSeenAt: longAgo } });

    await registerDevice(student.auth, { token: 'fcm-token-1', platform: 'ios' }).expect(204);

    const devices = await devicesOf(student.user._id);
    expect(devices).toHaveLength(1);
    expect(devices[0].platform).toBe('ios');
    expect(devices[0].lastSeenAt.getTime()).toBeGreaterThan(longAgo.getTime());
  });

  test('a token registered by another account moves to the caller (last sign-in wins)', async () => {
    const first = await createStudent();
    const second = await createStudent();
    await givePhones(first, 'shared-phone', 'first-own-phone');

    await givePhones(second, 'shared-phone');

    expect(await tokensOf(first.user._id)).toEqual(['first-own-phone']);
    expect(await tokensOf(second.user._id)).toEqual(['shared-phone']);
    expect(await PushDeviceModel.countDocuments({ token: 'shared-phone' })).toBe(1);
  });

  test(`keeps the ${MAX_DEVICES_PER_USER} most recently seen phones of a user`, async () => {
    const student = await createStudent();
    const other = await createStudent();
    const day = (n: number) => new Date(Date.UTC(2026, 0, 1 + n));
    await PushDeviceModel.insertMany([
      ...Array.from({ length: MAX_DEVICES_PER_USER }, (_, i) => ({
        userId: student.user._id,
        token: `old-${i}`,
        platform: 'android',
        lastSeenAt: day(i),
      })),
      { userId: other.user._id, token: 'other-0', platform: 'ios', lastSeenAt: day(-10) },
    ]);

    // Seeing a known phone again adds nothing.
    await givePhones(student, 'old-3');
    expect(await PushDeviceModel.countDocuments({ userId: student.user._id })).toBe(10);

    // An 11th phone pushes out the one seen least recently (old-0).
    await givePhones(student, 'new-phone');
    const tokens = await tokensOf(student.user._id);
    expect(tokens).toHaveLength(MAX_DEVICES_PER_USER);
    expect(tokens).not.toContain('old-0');
    expect(tokens).toEqual(expect.arrayContaining(['old-3', 'new-phone']));
    // Other accounts are not affected.
    expect(await tokensOf(other.user._id)).toEqual(['other-0']);
  });

  test('requires a session, of an account that still exists', async () => {
    await request(app)
      .put('/api/push/devices')
      .send({ token: 't', platform: 'android' })
      .expect(401);

    const student = await createStudent();
    await student.user.deleteOne();
    await registerDevice(student.auth, { token: 't', platform: 'android' }).expect(401);
    expect(await PushDeviceModel.countDocuments()).toBe(0);
  });

  test('validates the body', async () => {
    const student = await createStudent();
    const cases: [object, string][] = [
      [{ platform: 'android' }, 'Send the push token of this device'],
      [{ token: '   ', platform: 'android' }, 'Send the push token of this device'],
      [{ token: 42, platform: 'android' }, 'Send the push token of this device'],
      [
        { token: 'x'.repeat(4097), platform: 'android' },
        'The push token is too long (at most 4096 characters)',
      ],
      [{ token: 'fcm-token-1' }, 'Platform: android or ios'],
      [{ token: 'fcm-token-1', platform: 'web' }, 'Platform: android or ios'],
    ];
    for (const [body, message] of cases) {
      await registerDevice(student.auth, body).expect(422, validationError(message));
    }
    await registerDevice(student.auth, { token: 'x'.repeat(4096), platform: 'android' }).expect(204);
  });
});

describe('DELETE /api/push/devices', () => {
  test("removes the caller's phone only, and is idempotent", async () => {
    const student = await createStudent();
    await givePhones(student, 'phone-a', 'phone-b');

    await unregisterDevice(student.auth, { token: 'phone-a' }).expect(204, '');
    expect(await tokensOf(student.user._id)).toEqual(['phone-b']);

    await unregisterDevice(student.auth, { token: 'phone-a' }).expect(204);
    await unregisterDevice(student.auth, { token: 'never-registered' }).expect(204);
    expect(await tokensOf(student.user._id)).toEqual(['phone-b']);
  });

  test("leaves another account's phone alone", async () => {
    const owner = await createStudent();
    const stranger = await createStudent();
    await givePhones(owner, 'owner-phone');

    await unregisterDevice(stranger.auth, { token: 'owner-phone' }).expect(204);

    expect(await tokensOf(owner.user._id)).toEqual(['owner-phone']);
  });

  test('requires a session and a token', async () => {
    await request(app).delete('/api/push/devices').send({ token: 't' }).expect(401);
    const student = await createStudent();
    await unregisterDevice(student.auth, {}).expect(
      422,
      validationError('Send the push token of this device'),
    );
  });
});

describe('cleaning up phones', () => {
  /** Signs up through the API, so the account has a real refresh token. */
  async function signUp(email = 'sarra.kefi@campus.test') {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Sarra Kefi', email, password: 'password123' })
      .expect(201);
    const body = res.body as { user: { id: string }; accessToken: string; refreshToken: string };
    const auth = { Authorization: `Bearer ${body.accessToken}` };
    return { ...body, auth };
  }

  const logout = (body: object) => request(app).post('/api/auth/logout').send(body);

  test('logout with pushToken removes that phone and ends the session', async () => {
    const { auth, refreshToken, user } = await signUp();
    await registerDevice(auth, { token: 'this-phone', platform: 'android' }).expect(204);
    await registerDevice(auth, { token: 'other-phone', platform: 'ios' }).expect(204);

    await logout({ refreshToken, pushToken: 'this-phone' }).expect(204, '');

    expect(await PushDeviceModel.find({ userId: user.id }).distinct('token')).toEqual([
      'other-phone',
    ]);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401);
  });

  test("logout never removes another account's phone", async () => {
    const { refreshToken } = await signUp();
    const other = await createStudent();
    await givePhones(other, 'their-phone');

    await logout({ refreshToken, pushToken: 'their-phone' }).expect(204);

    expect(await tokensOf(other.user._id)).toEqual(['their-phone']);
  });

  test('logout works as before without a pushToken, with null and with unknown tokens', async () => {
    const { auth, refreshToken, user } = await signUp();
    await registerDevice(auth, { token: 'this-phone', platform: 'android' }).expect(204);

    await logout({ refreshToken }).expect(204);
    await logout({ refreshToken, pushToken: null }).expect(204);
    await logout({ refreshToken, pushToken: '' }).expect(204);
    await logout({ refreshToken: 'unknown', pushToken: 'this-phone' }).expect(204);
    expect(await PushDeviceModel.countDocuments({ userId: user.id })).toBe(1);

    // The session is over, but its refresh token still says whose phone it is.
    await logout({ refreshToken, pushToken: 'this-phone' }).expect(204);
    expect(await PushDeviceModel.countDocuments({ userId: user.id })).toBe(0);
  });

  test('logout validates the pushToken', async () => {
    const { refreshToken } = await signUp();
    await logout({ refreshToken, pushToken: 'x'.repeat(4097) }).expect(
      422,
      validationError('The push token is too long (at most 4096 characters)'),
    );
    await logout({ refreshToken, pushToken: 42 }).expect(
      422,
      validationError('The push token must be text'),
    );
    await logout({ pushToken: 'this-phone' }).expect(422, validationError('Missing refresh token'));
  });

  test("revokeAllSessions removes every phone of the user (and only theirs)", async () => {
    const student = await createStudent();
    const other = await createStudent();
    await givePhones(student, 'phone-a', 'phone-b');
    await givePhones(other, 'other-phone');

    await revokeAllSessions(student.user._id);

    expect(await tokensOf(student.user._id)).toEqual([]);
    expect(await tokensOf(other.user._id)).toEqual(['other-phone']);
  });

  test('a password reset signs every phone out', async () => {
    const { auth, user } = await signUp();
    await registerDevice(auth, { token: 'this-phone', platform: 'android' }).expect(204);
    await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'sarra.kefi@campus.test' })
      .expect(200);

    await request(app)
      .post('/api/auth/reset-password')
      .send({ email: 'sarra.kefi@campus.test', code: mail.resets[0].code, password: 'new-pass-456' })
      .expect(200);

    expect(await PushDeviceModel.countDocuments({ userId: user.id })).toBe(0);
  });

  test("an admin deleting an account removes the account's phones", async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    await givePhones(student, 'phone-a', 'phone-b');
    await givePhones(admin, 'admin-phone');

    await request(app).delete(`/api/admin/users/${student.user.id}`).set(admin.auth).expect(204);

    expect(await PushDeviceModel.countDocuments({ userId: student.user._id })).toBe(0);
    expect(await tokensOf(admin.user._id)).toEqual(['admin-phone']);
  });
});

describe('sending', () => {
  const changeAccount = (admin: TestAccount, user: TestAccount, body: object) =>
    request(app).patch(`/api/admin/users/${user.user.id}`).set(admin.auth).send(body).expect(200);

  /** The id `GET /api/notifications` gives the user's only account notification. */
  async function accountNotificationId(user: TestAccount): Promise<string> {
    const res = await request(app).get('/api/notifications').set(user.auth).expect(200);
    const account = (res.body as { id: string; category: string }[]).filter(
      (n) => n.category === 'account',
    );
    expect(account).toHaveLength(1);
    return account[0].id;
  }

  test("an admin role change is pushed to every phone of the user, and only theirs", async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    const bystander = await createStudent();
    await registerDevice(student.auth, { token: 'android-phone', platform: 'android' }).expect(204);
    await registerDevice(student.auth, { token: 'iphone', platform: 'ios' }).expect(204);
    await givePhones(admin, 'admin-phone');
    await givePhones(bystander, 'bystander-phone');

    await changeAccount(admin, student, { role: 'teacher' });
    await push.settle();

    const notificationId = await accountNotificationId(student);
    expect(sentTokens()).toEqual(['android-phone', 'iphone']);
    for (const message of push.messages) {
      expect(message).toEqual<PushMessage>({
        token: message.token,
        // The body without its markup ("Your role is now: **Teacher**.").
        notification: { title: 'Your account was updated', body: 'Your role is now: Teacher.' },
        data: {
          notificationId,
          category: 'account',
          destination: 'profile',
          targetId: '',
        },
        android: { priority: 'high', notification: { tag: notificationId } },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    }
  });

  test('a password change is still pushed to the phones it signs out', async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    await givePhones(student, 'phone-a', 'phone-b');

    await changeAccount(admin, student, { email: 'new.address@campus.test', password: 'new-pass-456' });
    await push.settle();

    expect(sentTokens()).toEqual(['phone-a', 'phone-b']);
    expect(push.messages[0].notification).toEqual({
      title: 'Your account was updated',
      body:
        'Your sign-in email is now new.address@campus.test.\n' +
        'An administrator changed your password: sign in with the new one.',
    });
    expect(await PushDeviceModel.countDocuments({ userId: student.user._id })).toBe(0);
  });

  test("an admin editing their own account pushes nothing", async () => {
    const admin = await createAdmin();
    await givePhones(admin, 'admin-phone');

    await changeAccount(admin, admin, { email: 'new.admin@campus.test' });
    await push.settle();

    expect(push.messages).toEqual([]);
  });

  test("a sign-up is pushed to every admin's phones, linked to the new account", async () => {
    const firstAdmin = await createAdmin();
    const secondAdmin = await createAdmin();
    const student = await createStudent();
    await givePhones(firstAdmin, 'admin-1-phone');
    await givePhones(secondAdmin, 'admin-2-phone', 'admin-2-tablet');
    await givePhones(student, 'student-phone');

    const res = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Sarra Kefi', email: 'sarra.kefi@campus.test', password: 'password123' })
      .expect(201);
    await push.settle();

    const newUserId = (res.body as { user: { id: string } }).user.id;
    expect(sentTokens()).toEqual(['admin-1-phone', 'admin-2-phone', 'admin-2-tablet']);
    const notifications = await NotificationModel.find({ category: 'account' }).lean();
    for (const message of push.messages) {
      expect(message.notification).toEqual({
        title: 'New account: Sarra Kefi',
        body: 'sarra.kefi@campus.test just signed up.',
      });
      expect(message.data).toMatchObject({
        category: 'account',
        destination: 'adminUsers',
        targetId: newUserId,
      });
      // Each admin's own notification id.
      const owner = message.token.startsWith('admin-1') ? firstAdmin : secondAdmin;
      const own = notifications.find((n) => n.userId.equals(owner.user._id));
      expect(message.data.notificationId).toBe(own?.key);
      expect(message.android.notification.tag).toBe(own?.key);
    }
  });

  test('a phone FCM no longer knows is deleted', async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    await givePhones(student, 'uninstalled-phone', 'live-phone');
    push.errors['uninstalled-phone'] = NOT_REGISTERED;

    await changeAccount(admin, student, { role: 'alumni' });
    await push.settle();

    expect(sentTokens()).toEqual(['live-phone', 'uninstalled-phone']);
    expect(await tokensOf(student.user._id)).toEqual(['live-phone']);
  });

  test('pushNotifications reports what happened to each phone', async () => {
    const student = await createStudent();
    await givePhones(student, 'ok-phone', 'dead-phone', 'invalid-phone', 'flaky-phone');
    push.errors['dead-phone'] = NOT_REGISTERED;
    push.errors['invalid-phone'] = 'messaging/invalid-registration-token';
    push.errors['flaky-phone'] = 'messaging/internal-error';
    const notification = await NotificationModel.create({
      userId: student.user._id,
      category: 'career',
      label: 'Career',
      title: 'Application viewed by InstaDeep',
      body: 'Your application for **Junior AI Intern** was viewed.',
      link: { destination: 'job', id: 'instadeep-ml' },
    });
    const logged = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    try {
      const report = await pushNotifications([notification]);

      expect(report).toEqual({ devices: 4, sent: 1, failed: 1, removed: 2 });
      expect(logged).toHaveBeenCalledWith(expect.stringContaining('messaging/internal-error'));
    } finally {
      logged.mockRestore();
    }
    // Only the phones FCM will never accept again are deleted.
    expect((await tokensOf(student.user._id)).sort()).toEqual(['flaky-phone', 'ok-phone']);
    expect(push.messages[0]).toMatchObject({
      notification: {
        title: 'Application viewed by InstaDeep',
        body: 'Your application for Junior AI Intern was viewed.',
      },
      data: {
        notificationId: notification.key,
        category: 'career',
        destination: 'job',
        targetId: 'instadeep-ml',
      },
    });
  });

  test('a user without phones gets nothing, and the report says so', async () => {
    const student = await createStudent();
    const notification = await NotificationModel.create({
      userId: student.user._id,
      category: 'community',
      label: 'CampusPulse',
      title: 'Push test',
      body: 'Hello',
    });

    expect(await pushNotifications([notification])).toEqual({
      devices: 0,
      sent: 0,
      failed: 0,
      removed: 0,
    });
    expect(push.messages).toEqual([]);
  });

  test('a failing FCM never fails the request', async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    await givePhones(student, 'phone-a');
    const logged = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setPushSender({ send: () => Promise.reject(new Error('FCM is down')) });
    try {
      await changeAccount(admin, student, { role: 'teacher' });
      await push.settle();

      expect(logged).toHaveBeenCalledWith(
        '[push] Could not send push notifications:',
        expect.any(Error),
      );
      // The phone is kept for the next push.
      expect(await tokensOf(student.user._id)).toEqual(['phone-a']);
    } finally {
      logged.mockRestore();
      capturePush(push); // back to capturing for the other tests
    }
  });

  test('push off: nothing is read or sent, and nothing fails', async () => {
    const admin = await createAdmin();
    const student = await createStudent();
    await givePhones(student, 'phone-a');
    setPushSender(null);
    const find = jest.spyOn(PushDeviceModel, 'find');
    try {
      expect(isPushOn()).toBe(false);
      await changeAccount(admin, student, { role: 'teacher' });
      await push.settle();
      const notification = await NotificationModel.findOne({ userId: student.user._id });
      expect(await pushNotifications([notification!])).toEqual({
        devices: 0,
        sent: 0,
        failed: 0,
        removed: 0,
      });

      expect(find).not.toHaveBeenCalled();
      expect(push.messages).toEqual([]);
      // The notification is still in the feed.
      expect(notification?.title).toBe('Your account was updated');
    } finally {
      find.mockRestore();
      capturePush(push);
    }
  });
});

describe('plainText', () => {
  test('keeps the text inside the markup, and the line breaks', () => {
    expect(
      plainText('Lecture at **10:15** moved from ~~Amphi 3B~~ to ==Grand Amphi C==.\nSee you there.'),
    ).toBe('Lecture at 10:15 moved from Amphi 3B to Grand Amphi C.\nSee you there.');
  });

  test('leaves unmatched or multi-line markers as they are, like the app', () => {
    expect(plainText('2 ** 3 and a == b')).toBe('2 ** 3 and a == b');
    expect(plainText('**not\nbold**')).toBe('**not\nbold**');
  });
});

describe('createFcmSender', () => {
  const message = (token: string): PushMessage => ({
    token,
    notification: { title: 't', body: 'b' },
    data: { notificationId: 'n', category: 'account', destination: '', targetId: '' },
    android: { priority: 'high', notification: { tag: 'n' } },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  test('sends through sendEach in batches of 500 and keeps the order of the answers', async () => {
    const sendEach = jest.fn(async (batch: PushMessage[]) => ({
      successCount: 0,
      failureCount: 0,
      responses: batch.map((m) =>
        m.token === 'gone'
          ? {
              success: false,
              error: { code: NOT_REGISTERED, message: 'Requested entity was not found.' },
            }
          : { success: true, messageId: `id-${m.token}` },
      ),
    }));
    const tokens = [...Array.from({ length: 501 }, (_, i) => `t${i}`), 'gone'];

    const results = await createFcmSender({ sendEach } as never).send(tokens.map(message));

    expect(sendEach.mock.calls.map(([batch]) => batch.length)).toEqual([500, 2]);
    expect(results).toHaveLength(502);
    expect(results[0]).toEqual({ ok: true });
    expect(results[501]).toEqual({
      ok: false,
      code: NOT_REGISTERED,
      message: 'Requested entity was not found.',
    });
  });
});

describe('initPush', () => {
  const scratch = mkdtempSync(path.join(tmpdir(), 'cp-push-'));
  afterAll(() => rmSync(scratch, { recursive: true, force: true }));
  const keyFile = (name: string, content: string) => {
    const file = path.join(scratch, name);
    writeFileSync(file, content);
    return file;
  };

  test('push stays off without FIREBASE_SERVICE_ACCOUNT_FILE, and says how to turn it on', async () => {
    const info = jest.spyOn(console, 'info').mockImplementation(() => undefined);
    try {
      // An empty value, as `FIREBASE_SERVICE_ACCOUNT_FILE=` in .env gives.
      expect(await initPush('')).toBe(false);
      expect(info).toHaveBeenCalledWith(
        '[push] Off: set FIREBASE_SERVICE_ACCOUNT_FILE to send push notifications.',
      );
    } finally {
      info.mockRestore();
    }
  });

  test('a missing or unusable key file keeps push off with a clear error (no crash)', async () => {
    const files: [string, RegExp][] = [
      [path.join(scratch, 'missing.json'), /\[push\] Off: cannot read .*missing\.json/],
      [keyFile('broken.json', '{ not json'), /broken\.json is not valid JSON/],
      [
        keyFile('google-services.json', JSON.stringify({ project_info: { project_id: 'x' } })),
        /google-services\.json is the app's google-services\.json, not a service account key/,
      ],
      [
        keyFile('partial.json', JSON.stringify({ project_id: 'campuspulse', client_email: 'a@b.c' })),
        /partial\.json is not a service account key \(no private_key\)/,
      ],
    ];
    const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    try {
      for (const [file, expected] of files) {
        error.mockClear();
        expect(await initPush(file)).toBe(false);
        expect(error).toHaveBeenCalledWith(expect.stringMatching(expected));
      }
      // The test sender is still the one in place.
      expect(isPushOn()).toBe(true);
    } finally {
      error.mockRestore();
    }
  });
});
