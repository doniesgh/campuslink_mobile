import express, { Router } from 'express';
import request from 'supertest';
import { z } from 'zod';

import {
  badRequest,
  conflict,
  forbidden,
  HttpError,
  notFound,
  tooManyRequests,
  unauthorized,
  unprocessable,
} from '../src/lib/http-error';
import { clientIp, requestContext, requestMeta } from '../src/lib/request-context';
import { parseQuery, validateBody } from '../src/lib/validate';
import { errorHandler } from '../src/middleware/error-handler';
import { signAccessToken } from '../src/modules/auth/tokens';
import { requireAuth } from '../src/middleware/require-auth';
import { validationError } from './helpers';

/** A tiny app that throws [error] on GET /boom, with the API's error handler. */
function throwing(error: unknown) {
  const app = express();
  app.get('/boom', () => {
    throw error;
  });
  app.use(errorHandler);
  return app;
}

describe('HttpError and the error handler', () => {
  test('sends the message alone when there is no code', async () => {
    const res = await request(throwing(notFound('Job not found.'))).get('/boom').expect(404);
    expect(res.body).toEqual({ message: 'Job not found.' });
  });

  test('sends the machine-readable code next to the message', async () => {
    const res = await request(throwing(new HttpError(503, 'AI is off.', undefined, 'AI_UNAVAILABLE')))
      .get('/boom')
      .expect(503);
    expect(res.body).toEqual({ message: 'AI is off.', code: 'AI_UNAVAILABLE' });
  });

  test('sends the details as extra fields, with or without a code', async () => {
    const problems = [{ row: 2, field: 'email', code: 'REQUIRED', message: 'Email: missing' }];
    await request(throwing(unprocessable('The file has errors.', { problems })))
      .get('/boom')
      .expect(422, { message: 'The file has errors.', problems });
    await request(throwing(unprocessable('Nope.', { field: 'email' }, 'EMAIL_TAKEN')))
      .get('/boom')
      .expect(422, { message: 'Nope.', code: 'EMAIL_TAKEN', field: 'email' });
  });

  test('every helper takes an optional code', () => {
    expect(badRequest('Bad.', 'OTP_INVALID')).toMatchObject({ status: 400, code: 'OTP_INVALID' });
    expect(unauthorized(undefined, 'TOKEN_EXPIRED')).toMatchObject({
      status: 401,
      message: 'Invalid credentials or expired session.',
      code: 'TOKEN_EXPIRED',
    });
    expect(forbidden()).toMatchObject({ status: 403, code: undefined });
    expect(notFound()).toMatchObject({ status: 404, message: 'Not found.' });
    expect(conflict('Taken.', 'EMAIL_TAKEN')).toMatchObject({ status: 409, code: 'EMAIL_TAKEN' });
    expect(tooManyRequests('Slow down.', 42)).toMatchObject({
      status: 429,
      code: 'TOO_MANY_REQUESTS',
      details: { retryAfter: 42 },
    });
  });
});

describe('validation errors', () => {
  const app = express();
  app.use(express.json());
  const router = Router();
  router.post(
    '/things',
    validateBody(z.object({ name: z.string({ error: 'Enter a name' }).min(1, 'Enter a name') })),
    (req, res) => {
      res.json(req.body);
    },
  );
  router.get('/things', (req, res) => {
    res.json(parseQuery(z.object({ page: z.coerce.number({ error: 'Pass a page' }) }), req.query));
  });
  app.use(router);
  app.use(errorHandler);

  test('a body refused by its schema is a 422 with the VALIDATION_ERROR code', async () => {
    await request(app).post('/things').send({}).expect(422, validationError('Enter a name'));
    await request(app).post('/things').send({ name: 'Sarra' }).expect(200, { name: 'Sarra' });
  });

  test('a query refused by its schema too', async () => {
    await request(app).get('/things?page=two').expect(422, validationError('Pass a page'));
    await request(app).get('/things?page=2').expect(200, { page: 2 });
  });
});

describe('request context', () => {
  const app = express();
  app.set('trust proxy', 1);
  app.get('/meta', (req, res) => {
    res.json({ ...requestMeta(req), ip2: clientIp(req) });
  });
  app.get('/context', requireAuth, (req, res) => {
    res.json(requestContext(req, res));
  });
  app.use(errorHandler);

  test('gives the IP (without the IPv4-mapped prefix) and the User-Agent', async () => {
    const res = await request(app).get('/meta').set('User-Agent', 'CampusPulse/1.0').expect(200);
    expect(res.body).toEqual({ ip: '127.0.0.1', ip2: '127.0.0.1', userAgent: 'CampusPulse/1.0' });
  });

  test('honours the proxy, cuts long User-Agents and gives null without one', async () => {
    const res = await request(app)
      .get('/meta')
      .set('X-Forwarded-For', '41.226.11.7')
      .set('User-Agent', 'x'.repeat(600))
      .expect(200);
    expect(res.body.ip).toBe('41.226.11.7');
    expect(res.body.userAgent).toHaveLength(512);

    const bare = await request(app).get('/meta').expect(200);
    expect(bare.body.userAgent).toBeNull();
  });

  test('adds the signed-in user as the actor', async () => {
    const token = signAccessToken('6aee283c10aef9a35cb4bcc6');
    const res = await request(app)
      .get('/context')
      .set('Authorization', `Bearer ${token}`)
      .set('User-Agent', 'Dart/3.13')
      .expect(200);
    expect(res.body).toEqual({
      actorId: '6aee283c10aef9a35cb4bcc6',
      ip: '127.0.0.1',
      userAgent: 'Dart/3.13',
    });
  });
});
