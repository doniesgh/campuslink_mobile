import request from 'supertest';

import { createApp } from '../src/app';

const app = createApp();

test('GET /api/health answers ok', async () => {
  await request(app).get('/api/health').expect(200, { status: 'ok' });
});

test('unknown routes answer 404 with a JSON message', async () => {
  const res = await request(app).get('/api/nope').expect(404);
  expect(res.body).toEqual({ message: 'Route GET /api/nope not found.' });
});

test('malformed JSON answers 400 with a JSON message', async () => {
  const res = await request(app)
    .post('/api/auth/login')
    .set('Content-Type', 'application/json')
    .send('{"identifier":')
    .expect(400);
  expect(res.body).toEqual({ message: 'Malformed request body.' });
});
