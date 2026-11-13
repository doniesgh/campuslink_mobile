import request from 'supertest';

import { createApp } from '../src/app';
import { setMailer } from '../src/modules/auth/mailer';
import { UserModel } from '../src/modules/users/user.model';
import { captureMail, clearTestDb, closeTestDb, connectTestDb, validationError } from './helpers';

const app = createApp();
const mail = captureMail();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(async () => {
  await clearTestDb();
  mail.resets.length = 0;
  mail.emails.length = 0;
});

const student = {
  displayName: 'Sarra Kefi',
  email: 'Sarra.Kefi@Campus.test',
  password: 'password123',
};

interface SessionBody {
  user: {
    id: string;
    email: string;
    studentId: string | null;
    isEmailVerified: boolean;
    role: string;
  };
  accessToken: string;
  refreshToken: string;
}

async function registerStudent(): Promise<SessionBody> {
  const res = await request(app).post('/api/auth/register').send(student).expect(201);
  return res.body as SessionBody;
}

const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

describe('POST /api/auth/register', () => {
  test('creates a verified account and signs in, without sending any email', async () => {
    const body = await registerStudent();

    expect(body.user).toEqual({
      id: expect.any(String),
      email: 'sarra.kefi@campus.test',
      studentId: null,
      displayName: 'Sarra Kefi',
      avatarUrl: null,
      isEmailVerified: true,
      role: 'student',
      locale: 'fr',
    });
    expect(body.accessToken).toEqual(expect.any(String));
    expect(body.refreshToken).toEqual(expect.any(String));
    expect(mail.emails).toEqual([]);
    const saved = await UserModel.findById(body.user.id).lean();
    expect(saved?.isEmailVerified).toBe(true);
    expect(Object.keys(saved ?? {}).join()).not.toMatch(/verification/i);
  });

  test('the new account can use the app right away', async () => {
    const { accessToken, user } = await registerStudent();
    const me = await request(app).get('/api/users/me').set(bearer(accessToken)).expect(200);
    expect(me.body).toEqual(user);
    await request(app).get('/api/notifications').set(bearer(accessToken)).expect(200);
  });

  test('there is no email verification step any more', async () => {
    const { accessToken } = await registerStudent();
    await request(app)
      .post('/api/auth/verify-email')
      .set(bearer(accessToken))
      .send({ code: '123456' })
      .expect(404);
    await request(app).post('/api/auth/resend-verification').set(bearer(accessToken)).expect(404);
  });

  test('rejects a second account with the same email, whatever the case', async () => {
    await registerStudent();
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...student, email: 'SARRA.KEFI@campus.test' })
      .expect(409);
    expect(res.body).toEqual({ message: 'An account with this email already exists.' });
  });

  test('answers 422 with a readable message for invalid data', async () => {
    const short = await request(app)
      .post('/api/auth/register')
      .send({ ...student, password: 'short' })
      .expect(422);
    expect(short.body).toEqual(validationError('Use at least 8 characters'));

    const missing = await request(app)
      .post('/api/auth/register')
      .send({ displayName: 'Sarra', password: 'password123' })
      .expect(422);
    expect(missing.body).toEqual(validationError('Enter your email'));

    const invalid = await request(app)
      .post('/api/auth/register')
      .send({ ...student, email: 'sarra.kefi' })
      .expect(422);
    expect(invalid.body).toEqual(validationError('Enter a valid email'));
  });
});

describe('POST /api/auth/login', () => {
  test('signs in with the email, whatever the case', async () => {
    await registerStudent();
    const res = await request(app)
      .post('/api/auth/login')
      .send({ identifier: '  SARRA.kefi@campus.TEST ', password: student.password })
      .expect(200);
    expect(res.body.user.email).toBe('sarra.kefi@campus.test');
    expect(res.body.accessToken).toEqual(expect.any(String));
  });

  test('signs in with the ENT ID, whatever the case', async () => {
    await registerStudent();
    await UserModel.updateOne({ email: 'sarra.kefi@campus.test' }, { studentId: '211JMT0428' });
    const res = await request(app)
      .post('/api/auth/login')
      .send({ identifier: '211jmt0428', password: student.password })
      .expect(200);
    expect(res.body.user.studentId).toBe('211JMT0428');
  });

  test('gives the same 401 for a wrong password and an unknown account', async () => {
    await registerStudent();
    const expected = { message: 'Invalid ENT ID/email or password.' };
    await request(app)
      .post('/api/auth/login')
      .send({ identifier: student.email, password: 'wrong-password' })
      .expect(401, expected);
    await request(app)
      .post('/api/auth/login')
      .send({ identifier: 'nobody@campus.test', password: 'whatever1' })
      .expect(401, expected);
    await request(app)
      .post('/api/auth/login')
      .send({ identifier: '000XXX0000', password: 'whatever1' })
      .expect(401, expected);
  });
});

describe('GET /api/users/me', () => {
  test('returns the signed-in user, unwrapped', async () => {
    const { accessToken, user } = await registerStudent();
    const res = await request(app).get('/api/users/me').set(bearer(accessToken)).expect(200);
    expect(res.body).toEqual(user);
  });

  test('answers 401 without a valid token', async () => {
    await request(app).get('/api/users/me').expect(401);
    await request(app).get('/api/users/me').set(bearer('not-a-jwt')).expect(401);
  });

  test('never sends password or code hashes', async () => {
    const { accessToken } = await registerStudent();
    const res = await request(app).get('/api/users/me').set(bearer(accessToken)).expect(200);
    expect(JSON.stringify(res.body)).not.toMatch(/Hash|password|verification/i);
  });
});

describe('POST /api/auth/refresh', () => {
  test('rotates the refresh token; the new access token works', async () => {
    const { refreshToken } = await registerStudent();
    const res = await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(200);
    expect(res.body).toEqual({ accessToken: expect.any(String), refreshToken: expect.any(String) });
    expect(res.body.refreshToken).not.toBe(refreshToken);
    await request(app).get('/api/users/me').set(bearer(res.body.accessToken)).expect(200);
  });

  test('reusing a rotated token fails and ends the newer session too', async () => {
    const { refreshToken } = await registerStudent();
    const rotated = await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(200);

    await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken })
      .expect(401, { message: 'Your session has expired. Please sign in again.' });
    await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: rotated.body.refreshToken })
      .expect(401);
  });

  test('rejects unknown tokens', async () => {
    await request(app).post('/api/auth/refresh').send({ refreshToken: 'nope' }).expect(401);
  });
});

describe('POST /api/auth/logout', () => {
  test('revokes the refresh token', async () => {
    const { refreshToken } = await registerStudent();
    await request(app).post('/api/auth/logout').send({ refreshToken }).expect(204);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401);
  });
});

describe('password reset', () => {
  test('forgot-password answers the same for an unknown email and sends nothing', async () => {
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'nobody@campus.test' })
      .expect(200);
    expect(res.body.message).toMatch(/If an account exists/);
    expect(mail.resets).toHaveLength(0);
  });

  const invalidReset = { message: 'Invalid or expired code. Check the email or request a new code.' };
  const reset = (body: object) => request(app).post('/api/auth/reset-password').send(body);

  test('the emailed 6-digit code sets a new password, once, and signs out everywhere', async () => {
    const { refreshToken } = await registerStudent();
    await request(app).post('/api/auth/forgot-password').send({ email: student.email }).expect(200);
    expect(mail.resets).toEqual([
      { to: 'sarra.kefi@campus.test', code: expect.stringMatching(/^\d{6}$/) },
    ]);
    const { code } = mail.resets[0];

    await reset({ email: student.email, code, password: 'new-password-456' }).expect(200);

    await request(app)
      .post('/api/auth/login')
      .send({ identifier: student.email, password: student.password })
      .expect(401);
    await request(app)
      .post('/api/auth/login')
      .send({ identifier: student.email, password: 'new-password-456' })
      .expect(200);
    await request(app).post('/api/auth/refresh').send({ refreshToken }).expect(401);

    // The code works once.
    await reset({ email: student.email, code, password: 'another-pass-789' }).expect(400, invalidReset);
  });

  test('locks the code after 5 wrong attempts', async () => {
    await registerStudent();
    await request(app).post('/api/auth/forgot-password').send({ email: student.email }).expect(200);
    const { code } = mail.resets[0];
    const wrong = code === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) {
      await reset({ email: student.email, code: wrong, password: 'new-password-456' }).expect(400);
    }
    await reset({ email: student.email, code, password: 'new-password-456' }).expect(400, invalidReset);
  });

  test('gives the same answer for an unknown email', async () => {
    await reset({ email: 'nobody@campus.test', code: '123456', password: 'new-password-456' }).expect(
      400,
      invalidReset,
    );
  });

  test('validates the code and the new password', async () => {
    await reset({ email: student.email, code: '12ab56', password: 'new-password-456' }).expect(
      422,
      validationError('Enter the 6-digit code'),
    );
    await reset({ email: student.email, code: '123456', password: 'short' }).expect(
      422,
      validationError('Use at least 8 characters'),
    );
  });
});

describe('when the mail server fails', () => {
  test('sign-up is not affected and forgot-password still answers', async () => {
    const failing = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setMailer({ sendPasswordResetCode: () => Promise.reject(new Error('SMTP down')) });
    try {
      await request(app).post('/api/auth/register').send(student).expect(201);
      await request(app).post('/api/auth/forgot-password').send({ email: student.email }).expect(200);
      expect(failing).toHaveBeenCalled();
    } finally {
      failing.mockRestore();
      captureMail(mail); // back to capturing for the other tests
    }
  });
});
