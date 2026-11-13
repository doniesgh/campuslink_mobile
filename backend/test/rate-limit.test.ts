import express from 'express';
import request from 'supertest';

import { createApp } from '../src/app';
import { errorHandler } from '../src/middleware/error-handler';
import {
  authIpLimit,
  createLimiter,
  DEFAULT_LIMIT_MESSAGE,
  enforceRateLimitsInTests,
  isLoopback,
  userLimit,
} from '../src/middleware/rate-limit';
import { requireAuth } from '../src/middleware/require-auth';
import { signAccessToken } from '../src/modules/auth/tokens';
import { captureMail, clearTestDb, closeTestDb, connectTestDb } from './helpers';

const tooMany = {
  message: DEFAULT_LIMIT_MESSAGE,
  code: 'TOO_MANY_REQUESTS',
  retryAfter: expect.any(Number),
};

/** An app with [limiter] on GET /ping (trusting one proxy, so tests can pick the IP). */
function appWith(limiter: express.RequestHandler, ...before: express.RequestHandler[]) {
  const app = express();
  app.set('trust proxy', 1);
  app.get('/ping', ...before, limiter, (_req, res) => {
    res.json({ ok: true });
  });
  app.use(errorHandler);
  return app;
}

afterEach(() => enforceRateLimitsInTests(false));

describe('createLimiter', () => {
  test('is off in tests unless a test turns it on', async () => {
    const app = appWith(createLimiter({ name: 'off', limit: 1, windowMs: 60_000, key: () => 'k' }));
    for (let i = 0; i < 3; i++) await request(app).get('/ping').expect(200);
  });

  test('answers 429 with the code, retryAfter and a Retry-After header past the limit', async () => {
    enforceRateLimitsInTests();
    const app = appWith(createLimiter({ name: 'two', limit: 2, windowMs: 60_000, key: () => 'k' }));

    await request(app).get('/ping').expect(200);
    await request(app).get('/ping').expect(200);
    const res = await request(app).get('/ping').expect(429);

    expect(res.body).toEqual(tooMany);
    expect(res.body.retryAfter).toBeGreaterThan(0);
    expect(res.body.retryAfter).toBeLessThanOrEqual(60);
    expect(res.headers['retry-after']).toBe(String(res.body.retryAfter));
    expect(res.headers['ratelimit-policy']).toContain('"two"');
  });

  test('counts each key apart, and lets a null key through uncounted', async () => {
    enforceRateLimitsInTests();
    const app = appWith(
      createLimiter({
        name: 'keyed',
        limit: 1,
        windowMs: 60_000,
        key: (req) => (req.get('x-key') === 'free' ? null : (req.get('x-key') ?? 'none')),
        message: 'Slow down.',
      }),
    );
    await request(app).get('/ping').set('x-key', 'a').expect(200);
    await request(app).get('/ping').set('x-key', 'b').expect(200);
    await request(app)
      .get('/ping')
      .set('x-key', 'a')
      .expect(429)
      .expect((res) => expect(res.body.message).toBe('Slow down.'));
    for (let i = 0; i < 3; i++) await request(app).get('/ping').set('x-key', 'free').expect(200);
  });

  test('enforceRateLimitsInTests starts every counter from zero', async () => {
    enforceRateLimitsInTests();
    const app = appWith(createLimiter({ name: 'reset', limit: 1, windowMs: 60_000, key: () => 'k' }));
    await request(app).get('/ping').expect(200);
    await request(app).get('/ping').expect(429);
    enforceRateLimitsInTests();
    await request(app).get('/ping').expect(200);
  });
});

describe('userLimit', () => {
  test('counts per signed-in user (after requireAuth)', async () => {
    enforceRateLimitsInTests();
    const app = appWith(userLimit({ name: 'summary', limit: 1, windowMs: 3_600_000 }), requireAuth);
    const sarra = { Authorization: `Bearer ${signAccessToken('6aee283c10aef9a35cb4bcc6')}` };
    const omar = { Authorization: `Bearer ${signAccessToken('6aee283c10aef9a35cb4bcc7')}` };

    await request(app).get('/ping').set(sarra).expect(200);
    await request(app).get('/ping').set(omar).expect(200);
    const res = await request(app).get('/ping').set(sarra).expect(429);
    expect(res.body.retryAfter).toBeGreaterThan(60);
  });

  test('falls back to the IP without a signed-in user', async () => {
    enforceRateLimitsInTests();
    const app = appWith(userLimit({ name: 'anonymous', limit: 1, windowMs: 60_000 }));
    await request(app).get('/ping').set('X-Forwarded-For', '41.0.0.1').expect(200);
    await request(app).get('/ping').set('X-Forwarded-For', '41.0.0.2').expect(200);
    await request(app).get('/ping').set('X-Forwarded-For', '41.0.0.1').expect(429);
  });
});

test('authIpLimit counts every auth request of an IP, but not loopback ones', async () => {
  enforceRateLimitsInTests();
  const app = appWith(authIpLimit);
  const from = (ip: string) => request(app).get('/ping').set('X-Forwarded-For', ip);
  // 500 per 15 minutes outside production (100 in production).
  for (let i = 0; i < 500; i++) await from('41.226.11.7').expect(200);
  await from('41.226.11.7').expect(429);
  await from('41.226.11.8').expect(200);
  // The emulator or a developer on this machine (no proxy in front).
  for (let i = 0; i < 3; i++) await request(app).get('/ping').expect(200);
}, 60_000);

test('isLoopback knows the local addresses', () => {
  for (const ip of ['127.0.0.1', '127.8.0.1', '::1', '::ffff:127.0.0.1']) {
    expect(isLoopback(ip)).toBe(true);
  }
  for (const ip of ['10.0.2.2', '41.226.11.7', '::ffff:41.226.11.7', '2001:db8::1', '', undefined]) {
    expect(isLoopback(ip)).toBe(false);
  }
});

describe('the auth routes', () => {
  const app = createApp();
  captureMail();

  beforeAll(connectTestDb);
  afterAll(closeTestDb);
  beforeEach(async () => {
    await clearTestDb();
    enforceRateLimitsInTests();
  });

  // Without a password the body is refused (422) at once, without bcrypt: the
  // limiter runs before the validation, so these attempts count all the same.
  const login = (identifier: string) => request(app).post('/api/auth/login').send({ identifier });

  test('login allows 100 tries per account and IP in 15 minutes outside production', async () => {
    for (let i = 0; i < 100; i++) await login('Sarra@Campus.test').expect(422);
    // The email is normalised: another spelling is the same account.
    const res = await login(' sarra@campus.test ').expect(429);
    expect(res.body).toEqual(tooMany);
    expect(res.headers['retry-after']).toBeDefined();
    // Another account from the same (loopback) IP is not blocked.
    await login('omar@campus.test').expect(422);
  }, 60_000);

  test('the limit is per route: forgot-password keeps its own counter', async () => {
    for (let i = 0; i < 100; i++) await login('sarra@campus.test').expect(422);
    await login('sarra@campus.test').expect(429);
    await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'sarra@campus.test' })
      .expect(200);
  }, 60_000);

  test('refresh and logout have no limit', async () => {
    for (let i = 0; i < 120; i++) {
      await request(app).post('/api/auth/refresh').send({ refreshToken: 'nope' }).expect(401);
    }
  }, 60_000);
});
