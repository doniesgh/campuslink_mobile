import mongoose from 'mongoose';
import request from 'supertest';

import { createApp } from '../src/app';
import { localeFromAcceptLanguage, pickLocale } from '../src/lib/i18n';
import { AuditLogModel } from '../src/modules/admin/audit-log.model';
import { passwordResetEmail } from '../src/modules/auth/mailer';
import {
  backfillLocale,
  toPublicUser,
  UserModel,
  type UserDocument,
} from '../src/modules/users/user.model';
import {
  captureMail,
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  validationError,
} from './helpers';

const app = createApp();
const mail = captureMail();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(async () => {
  await clearTestDb();
  mail.resets.length = 0;
  mail.emails.length = 0;
});

const newStudent = { displayName: 'Sarra Kefi', email: 'sarra.kefi@campus.test', password: 'password123' };

const patchMe = (auth: { Authorization: string }, body: object) =>
  request(app).patch('/api/users/me').set(auth).send(body);

describe('PATCH /api/users/me', () => {
  test('needs a signed-in user', async () => {
    await request(app).patch('/api/users/me').send({ locale: 'en' }).expect(401);
  });

  test('changes the language and sends the account back', async () => {
    const { user, auth } = await createStudent();
    expect(user.locale).toBe('fr');

    const res = await patchMe(auth, { locale: 'en' }).expect(200);

    expect(res.body).toMatchObject({ id: user.id, email: user.email, role: 'student', locale: 'en' });
    expect((await UserModel.findById(user.id))?.locale).toBe('en');
    await request(app).get('/api/users/me').set(auth).expect(200).expect((r) => {
      expect(r.body.locale).toBe('en');
    });
  });

  test('accepts any case, and the current value', async () => {
    const { auth } = await createStudent();
    await patchMe(auth, { locale: ' FR ' }).expect(200).expect((r) => expect(r.body.locale).toBe('fr'));
  });

  test('ignores the fields a user may not change', async () => {
    const { user, auth } = await createStudent();
    const res = await patchMe(auth, { locale: 'en', role: 'admin', email: 'boss@campus.test' }).expect(200);
    expect(res.body).toMatchObject({ role: 'student', email: user.email, locale: 'en' });
  });

  test.each([
    [{}, "There's nothing to save."],
    [{ role: 'admin' }, "There's nothing to save."],
    [{ locale: 'de' }, 'Language: choose fr or en'],
    [{ locale: 42 }, 'Language: choose fr or en'],
  ])('answers 422 for %j', async (body, message) => {
    const { auth } = await createStudent();
    await patchMe(auth, body).expect(422, validationError(message));
  });

  test('answers 401 for a deleted account', async () => {
    const { user, auth } = await createStudent();
    await user.deleteOne();
    await patchMe(auth, { locale: 'en' }).expect(401);
  });
});

describe('the language of an account', () => {
  test('sign-up takes the locale sent (and sends no email)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({ ...newStudent, locale: 'en' })
      .expect(201);
    expect(res.body.user.locale).toBe('en');
    expect((await UserModel.findById(res.body.user.id))?.locale).toBe('en');
    expect(mail.emails).toEqual([]);
  });

  test('without one, sign-up takes the Accept-Language header, else French', async () => {
    const en = await request(app)
      .post('/api/auth/register')
      .set('Accept-Language', 'en-GB,en;q=0.9')
      .send(newStudent)
      .expect(201);
    expect(en.body.user.locale).toBe('en');

    const fr = await request(app)
      .post('/api/auth/register')
      .set('Accept-Language', 'de-DE')
      .send({ ...newStudent, email: 'omar@campus.test' })
      .expect(201);
    expect(fr.body.user.locale).toBe('fr');
  });

  test('sign-up refuses an unknown locale', async () => {
    await request(app)
      .post('/api/auth/register')
      .send({ ...newStudent, locale: 'es' })
      .expect(422, validationError('Language: choose fr or en'));
  });

  test("the reset code is in the account's language", async () => {
    const { body } = await request(app).post('/api/auth/register').send(newStudent).expect(201);
    const auth = { Authorization: `Bearer ${body.accessToken as string}` };
    await patchMe(auth, { locale: 'en' }).expect(200);

    await request(app).post('/api/auth/forgot-password').send({ email: newStudent.email }).expect(200);

    expect(mail.emails).toEqual([{ kind: 'reset', to: newStudent.email, locale: 'en' }]);
  });

  test('backfillLocale gives French to the older accounts, and only them', async () => {
    const { user: english } = await createStudent();
    english.locale = 'en';
    await english.save();
    // An account saved before languages existed.
    const { insertedId } = await mongoose.connection.collection('users').insertOne({
      email: 'old@campus.test',
      displayName: 'Old Account',
      role: 'student',
      passwordHash: 'x',
      isEmailVerified: true,
    });
    const old = (await UserModel.findById(insertedId)) as UserDocument;
    expect(toPublicUser(old).locale).toBe('fr');

    expect(await backfillLocale()).toBe(1);
    expect(await backfillLocale()).toBe(0);
    const raw = await mongoose.connection.collection('users').findOne({ _id: insertedId });
    expect(raw?.locale).toBe('fr');
    expect((await UserModel.findById(english.id))?.locale).toBe('en');
  });
});

describe('the password reset is in the audit log', () => {
  test('recorded by the user, with the IP and the User-Agent', async () => {
    const { body } = await request(app).post('/api/auth/register').send(newStudent).expect(201);
    await request(app).post('/api/auth/forgot-password').send({ email: newStudent.email }).expect(200);
    await request(app)
      .post('/api/auth/reset-password')
      .set('User-Agent', 'Dart/3.13 (dart:io)')
      .send({ email: newStudent.email, code: mail.resets[0].code, password: 'new-password-456' })
      .expect(200);

    const admin = await createAdmin();
    const page = await request(app)
      .get('/api/admin/audit')
      .query({ action: 'auth.*' })
      .set(admin.auth)
      .expect(200);
    expect(page.body.items).toEqual([
      {
        id: expect.any(String),
        action: 'auth.password_reset',
        summary: 'Password reset with an emailed code for sarra.kefi@campus.test',
        actor: { id: body.user.id, displayName: 'Sarra Kefi', email: 'sarra.kefi@campus.test' },
        targetType: 'user',
        targetId: body.user.id,
        metadata: {},
        ip: '127.0.0.1',
        userAgent: 'Dart/3.13 (dart:io)',
        createdAt: expect.any(String),
      },
    ]);
  });

  test('a failed reset records nothing', async () => {
    await request(app).post('/api/auth/register').send(newStudent).expect(201);
    await request(app)
      .post('/api/auth/reset-password')
      .send({ email: newStudent.email, code: '123456', password: 'new-password-456' })
      .expect(400);
    expect(await AuditLogModel.countDocuments()).toBe(0);
  });
});

describe('company accounts', () => {
  test('an admin creates one; it has no timetable and no courses', async () => {
    const admin = await createAdmin();
    const created = await request(app)
      .post('/api/admin/users')
      .set(admin.auth)
      .send({
        displayName: 'Nadia Kooli',
        email: 'nadia.kooli@campus.test',
        password: 'password123',
        role: 'company',
      })
      .expect(201);
    expect(created.body.role).toBe('company');

    const audit = await AuditLogModel.findOne({ action: 'user.create' });
    expect(audit?.summary).toBe('Created the company account nadia.kooli@campus.test');

    const company = await createStudent({ role: 'company' });
    await request(app).get('/api/users/me').set(company.auth).expect(200).expect((r) => {
      expect(r.body.role).toBe('company');
    });
    await request(app)
      .get('/api/timetable/day')
      .query({ date: '2026-11-05' })
      .set(company.auth)
      .expect(403);
    await request(app).get('/api/courses').set(company.auth).expect(403);
  });

  test('a user import accepts the company role', async () => {
    const admin = await createAdmin();
    const res = await request(app)
      .post('/api/admin/users/import')
      .set(admin.auth)
      .send({
        dryRun: false,
        users: [
          {
            displayName: 'Walid Sassi',
            email: 'walid.sassi@campus.test',
            password: 'password123',
            role: 'company',
          },
        ],
      })
      .expect(201);
    expect(res.body.created[0].role).toBe('company');
  });

  test('the account notification names the new role', async () => {
    const admin = await createAdmin();
    const target = await createStudent();
    await request(app)
      .patch(`/api/admin/users/${target.user.id}`)
      .set(admin.auth)
      .send({ role: 'company' })
      .expect(200);
    const feed = await request(app).get('/api/notifications').set(target.auth).expect(200);
    expect(JSON.stringify(feed.body)).toContain('Your role is now: **Company**.');
  });
});

describe('i18n helpers', () => {
  test('pickLocale reads fr and en, any case or region', () => {
    expect(pickLocale('fr')).toBe('fr');
    expect(pickLocale(' EN ')).toBe('en');
    expect(pickLocale('en-GB')).toBe('en');
    expect(pickLocale('fr_TN')).toBe('fr');
    expect(pickLocale('ar')).toBeNull();
    expect(pickLocale(undefined)).toBeNull();
    expect(pickLocale(1)).toBeNull();
  });

  test('localeFromAcceptLanguage honours the order and the q-values', () => {
    expect(localeFromAcceptLanguage('en')).toBe('en');
    expect(localeFromAcceptLanguage('ar-TN,fr;q=0.8,en;q=0.5')).toBe('fr');
    expect(localeFromAcceptLanguage('fr;q=0.4, en;q=0.9')).toBe('en');
    expect(localeFromAcceptLanguage('de, *;q=0.1')).toBeNull();
    expect(localeFromAcceptLanguage('en;q=0, fr')).toBe('fr');
    expect(localeFromAcceptLanguage('')).toBeNull();
    expect(localeFromAcceptLanguage(undefined)).toBeNull();
  });
});

describe('localised emails', () => {
  test('French emails say "tu"; English stays the default', () => {
    const fr = passwordResetEmail('123456', 'fr');
    expect(fr.subject).toBe('Réinitialise ton mot de passe CampusPulse');
    expect(fr.text).toContain('123456');
    expect(fr.text).toContain("Si tu n'es pas à l'origine de cette demande");
    expect(fr.text).toContain('ton mot de passe ne changera pas');
    expect(fr.html).toContain('lang="fr"');

    expect(passwordResetEmail('042917').subject).toBe('Reset your CampusPulse password');
    expect(passwordResetEmail('042917', 'en').html).toContain('lang="en"');
  });
});
