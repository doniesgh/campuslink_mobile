import request from 'supertest';

import { createApp } from '../src/app';
import { ForumPostModel } from '../src/modules/forum/forum-post.model';
import { seedForum } from '../src/modules/forum/forum.seed';
import { HIGHLIGHTS_LIMIT } from '../src/modules/forum/forum.service';
import { LostItemModel } from '../src/modules/forum/lost-item.model';
import { LostItemRequestModel } from '../src/modules/forum/lost-item-request.model';
import { clearTestDb, closeTestDb, connectTestDb, createStudent } from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

const MINUTE_MS = 60 * 1000;
const ago = (minutes: number) => new Date(Date.now() - minutes * MINUTE_MS);

function addPost(id: string, postedAt: Date, extra: Record<string, unknown> = {}) {
  return ForumPostModel.create({
    _id: id,
    authorName: 'Sarra K.',
    authorInfo: '5A - Informatique',
    category: 'carpool',
    tag: '2 places',
    body: 'Départ à 13h15',
    postedAt,
    ...extra,
  });
}

function addItem(id: string, reportedAt: Date, extra: Record<string, unknown> = {}) {
  return LostItemModel.create({
    _id: id,
    kind: 'found',
    title: 'Calculatrice TI-84 Plus CE',
    category: 'calculator',
    zone: 'Bloc C',
    location: 'Salle C12 (Ghazela)',
    place: 'classroom',
    reporterName: 'Youssef M.',
    reportedAt,
    ...extra,
  });
}

const ids = (body: { id: string }[]) => body.map((x) => x.id);

describe('authentication', () => {
  test('every forum route answers 401 without a valid token', async () => {
    await addItem('lf-1', ago(5));
    await request(app).get('/api/forum/highlights').expect(401);
    await request(app).get('/api/forum/lost-items').expect(401);
    await request(app)
      .post('/api/forum/lost-items/lf-1/requests')
      .send({ proof: 'Autocollant' })
      .expect(401);
    await request(app)
      .get('/api/forum/highlights')
      .set({ Authorization: 'Bearer not-a-jwt' })
      .expect(401);
    expect(await LostItemRequestModel.countDocuments()).toBe(0);
  });
});

describe('GET /api/forum/highlights', () => {
  test('returns the posts newest first, in the app shape', async () => {
    const { auth } = await createStudent();
    await addPost('post-old', ago(120), { category: 'idea', upvotes: 42, comments: 8 });
    await addPost('post-new', ago(12), { place: 'Passage → Ghazela' });
    await addPost('post-mid', ago(45), { category: 'lostFound', status: 'En examen BDE' });

    const res = await request(app).get('/api/forum/highlights').set(auth).expect(200);

    expect(ids(res.body)).toEqual(['post-new', 'post-mid', 'post-old']);
    expect(res.body[0]).toEqual({
      id: 'post-new',
      authorName: 'Sarra K.',
      authorInfo: '5A - Informatique',
      category: 'carpool',
      tag: '2 places',
      body: 'Départ à 13h15',
      place: 'Passage → Ghazela',
      upvotes: 0,
      comments: 0,
      status: null,
      postedAt: expect.stringMatching(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/),
      isUpvotedByMe: false,
    });
    expect(res.body[2]).toMatchObject({ category: 'idea', upvotes: 42, comments: 8, place: null });
    expect(res.body[1]).toMatchObject({ category: 'lostFound', status: 'En examen BDE' });
  });

  test(`keeps only the ${HIGHLIGHTS_LIMIT} latest posts`, async () => {
    const { auth } = await createStudent();
    for (let i = 0; i < HIGHLIGHTS_LIMIT + 2; i++) await addPost(`post-${i}`, ago(i));

    const res = await request(app).get('/api/forum/highlights').set(auth).expect(200);

    expect(res.body).toHaveLength(HIGHLIGHTS_LIMIT);
    expect(res.body[0].id).toBe('post-0');
  });

  test('is an empty list when there are no posts', async () => {
    const { auth } = await createStudent();
    await request(app).get('/api/forum/highlights').set(auth).expect(200, []);
  });
});

describe('GET /api/forum/lost-items', () => {
  test('returns the board newest first, in the app shape', async () => {
    const { auth } = await createStudent();
    await addItem('lf-398', new Date('2026-11-03T16:00:00.000Z'), {
      kind: 'lost',
      category: 'bag',
    });
    await addItem('lf-409', new Date('2026-11-06T12:15:00.000Z'), {
      reference: 'TF-409',
      photoCount: 1,
    });
    await addItem('lf-406', new Date('2026-11-05T15:30:00.000Z'), {
      kind: 'lost',
      category: 'keys',
      place: 'parking',
      isUrgent: true,
      reward: 'Café offert ☕',
    });

    const res = await request(app).get('/api/forum/lost-items').set(auth).expect(200);

    expect(ids(res.body)).toEqual(['lf-409', 'lf-406', 'lf-398']);
    expect(res.body[0]).toEqual({
      id: 'lf-409',
      kind: 'found',
      title: 'Calculatrice TI-84 Plus CE',
      category: 'calculator',
      zone: 'Bloc C',
      location: 'Salle C12 (Ghazela)',
      place: 'classroom',
      reporterName: 'Youssef M.',
      reporterIsStaff: false,
      reportedAt: '2026-11-06T12:15:00.000Z',
      reference: 'TF-409',
      photoCount: 1,
      isUrgent: false,
      reward: null,
      distinctiveDetail: null,
      dropOffNote: null,
      pickupDesk: null,
      isSerialHidden: false,
    });
    expect(res.body[1]).toMatchObject({ kind: 'lost', isUrgent: true, reward: 'Café offert ☕' });
  });

  test('never exposes who sent requests', async () => {
    const { auth } = await createStudent();
    const other = await createStudent();
    await addItem('lf-409', ago(45));
    await request(app)
      .post('/api/forum/lost-items/lf-409/requests')
      .set(other.auth)
      .send({ proof: 'Autocollant ESPRIT au dos' })
      .expect(201);

    const res = await request(app).get('/api/forum/lost-items').set(auth).expect(200);
    expect(JSON.stringify(res.body)).not.toMatch(/Autocollant|userId|proof/);
  });
});

describe('POST /api/forum/lost-items/:id/requests', () => {
  test('stores the request with its sender and time', async () => {
    const { user, auth } = await createStudent();
    await addItem('lf-409', ago(45));
    const before = Date.now();

    const res = await request(app)
      .post('/api/forum/lost-items/lf-409/requests')
      .set(auth)
      .send({ proof: '  Autocollant ESPRIT au dos  ' })
      .expect(201);

    expect(res.body).toEqual({
      id: expect.any(String),
      itemId: 'lf-409',
      proof: 'Autocollant ESPRIT au dos',
      createdAt: expect.any(String),
    });
    const stored = await LostItemRequestModel.findById(res.body.id).lean();
    expect(stored?.userId.toString()).toBe(user.id);
    expect(stored?.itemId).toBe('lf-409');
    expect(stored?.proof).toBe('Autocollant ESPRIT au dos');
    expect(stored?.createdAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(new Date(res.body.createdAt).getTime()).toBe(stored?.createdAt.getTime());
  });

  test('answers 422 with a readable message for a blank or missing proof', async () => {
    const { auth } = await createStudent();
    await addItem('lf-409', ago(45));
    const expected = { message: 'Please add a detail that identifies the item.' };

    for (const body of [{ proof: '' }, { proof: '   \n ' }, {}, { proof: 42 }]) {
      await request(app)
        .post('/api/forum/lost-items/lf-409/requests')
        .set(auth)
        .send(body)
        .expect(422, expected);
    }
    await request(app)
      .post('/api/forum/lost-items/lf-409/requests')
      .set(auth)
      .send({ proof: 'x'.repeat(501) })
      .expect(422, { message: 'Keep the detail under 500 characters.' });
    expect(await LostItemRequestModel.countDocuments()).toBe(0);
  });

  test('answers 404 for an unknown item', async () => {
    const { auth } = await createStudent();
    await request(app)
      .post('/api/forum/lost-items/lf-000/requests')
      .set(auth)
      .send({ proof: 'Autocollant' })
      .expect(404, { message: 'This item is no longer listed.' });
    expect(await LostItemRequestModel.countDocuments()).toBe(0);
  });

  test('refuses a second request from the same student with 409', async () => {
    const { auth } = await createStudent();
    await addItem('lf-409', ago(45));
    const send = (proof: string) =>
      request(app).post('/api/forum/lost-items/lf-409/requests').set(auth).send({ proof });

    await send('Autocollant ESPRIT au dos').expect(201);
    await send('Rayure sur l’écran').expect(409, {
      message:
        'You already sent a request for this item. The security desk will get back to you.',
    });
    expect(await LostItemRequestModel.countDocuments()).toBe(1);
  });

  test('two taps at once still store a single request', async () => {
    const { auth } = await createStudent();
    await addItem('lf-409', ago(45));
    const send = () =>
      request(app)
        .post('/api/forum/lost-items/lf-409/requests')
        .set(auth)
        .send({ proof: 'Autocollant' });

    const statuses = (await Promise.all([send(), send()])).map((r) => r.status).sort();
    expect(statuses).toEqual([201, 409]);
    expect(await LostItemRequestModel.countDocuments()).toBe(1);
  });

  test('other students can still send their own request for the same item', async () => {
    const first = await createStudent();
    const second = await createStudent();
    await addItem('lf-409', ago(45));

    for (const { auth } of [first, second]) {
      await request(app)
        .post('/api/forum/lost-items/lf-409/requests')
        .set(auth)
        .send({ proof: 'Autocollant' })
        .expect(201);
    }
    expect(await LostItemRequestModel.countDocuments({ itemId: 'lf-409' })).toBe(2);
  });
});

describe('seedForum', () => {
  // 14:00 in Tunis (UTC+1).
  const now = new Date('2026-11-06T13:00:00.000Z');

  test('ports the app mock: same ids, content and relative dates', async () => {
    const demo = await createStudent();
    await seedForum(demo.user._id, now);

    const posts = await request(app).get('/api/forum/highlights').set(demo.auth).expect(200);
    expect(posts.body.map((p: { id: string; postedAt: string }) => [p.id, p.postedAt])).toEqual([
      ['post-1', '2026-11-06T12:48:00.000Z'], // 12 min ago
      ['post-2', '2026-11-06T12:15:00.000Z'], // 45 min ago
      ['post-3', '2026-11-06T11:00:00.000Z'], // 2 h ago
    ]);
    expect(posts.body[0]).toMatchObject({
      authorName: 'Sarra K.',
      authorInfo: '5A - Informatique',
      category: 'carpool',
      tag: '2 places',
      place: 'Passage → Ghazela',
    });
    expect(posts.body[2]).toMatchObject({
      category: 'idea',
      upvotes: 42,
      comments: 8,
      status: 'En examen BDE',
      place: null,
    });

    const items = await request(app).get('/api/forum/lost-items').set(demo.auth).expect(200);
    expect(items.body.map((i: { id: string; reportedAt: string }) => [i.id, i.reportedAt])).toEqual(
      [
        ['lf-409', '2026-11-06T12:15:00.000Z'], // 45 min ago
        ['lf-411', '2026-11-06T10:00:00.000Z'], // 3 h ago, on the hour (11h in Tunis)
        ['lf-406', '2026-11-05T15:30:00.000Z'], // yesterday 16h30 in Tunis
        ['lf-404', '2026-11-05T08:45:00.000Z'], // yesterday 9h45 in Tunis
        ['lf-402', '2026-11-04T12:00:00.000Z'], // 2 days ago 13h in Tunis
        ['lf-398', '2026-11-03T16:00:00.000Z'], // 3 days ago 17h in Tunis
      ],
    );
    expect(items.body[1]).toMatchObject({
      title: 'Sony WH-1000XM4 (Étui)',
      reporterIsStaff: true,
      isSerialHidden: true,
      photoCount: 2,
    });
  });

  test('is visible to a brand-new student too', async () => {
    const demo = await createStudent();
    await seedForum(demo.user._id, now);
    const newcomer = await createStudent();

    const posts = await request(app).get('/api/forum/highlights').set(newcomer.auth).expect(200);
    const items = await request(app).get('/api/forum/lost-items').set(newcomer.auth).expect(200);
    expect(posts.body).toHaveLength(3);
    expect(items.body).toHaveLength(6);
  });

  test('is idempotent, refreshes the dates and resets only the demo requests', async () => {
    const demo = await createStudent();
    const other = await createStudent();
    await seedForum(demo.user._id, now);
    for (const { auth } of [demo, other]) {
      await request(app)
        .post('/api/forum/lost-items/lf-409/requests')
        .set(auth)
        .send({ proof: 'Autocollant' })
        .expect(201);
    }

    const later = new Date(now.getTime() + 24 * 60 * MINUTE_MS);
    await seedForum(demo.user._id, later);

    expect(await ForumPostModel.countDocuments()).toBe(3);
    expect(await LostItemModel.countDocuments()).toBe(6);
    const first = await LostItemModel.findById('lf-409').lean();
    expect(first?.reportedAt.toISOString()).toBe('2026-11-07T12:15:00.000Z');
    expect(await LostItemRequestModel.countDocuments({ userId: demo.user._id })).toBe(0);
    expect(await LostItemRequestModel.countDocuments({ userId: other.user._id })).toBe(1);

    // The demo student can show the claim flow again.
    await request(app)
      .post('/api/forum/lost-items/lf-409/requests')
      .set(demo.auth)
      .send({ proof: 'Autocollant' })
      .expect(201);
  });
});
