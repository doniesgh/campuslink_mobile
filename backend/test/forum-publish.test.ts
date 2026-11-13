import request from 'supertest';

import { createApp } from '../src/app';
import { ForumPostModel } from '../src/modules/forum/forum-post.model';
import { seedForum } from '../src/modules/forum/forum.seed';
import { IdeaVoteModel } from '../src/modules/forum/idea-vote.model';
import { LostItemModel } from '../src/modules/forum/lost-item.model';
import { StudentProfileModel } from '../src/modules/profile/profile.model';
import { clearTestDb, closeTestDb, connectTestDb, createStudent, validationError } from './helpers';

// Publishing in the forum: Lost & Found notices, ideas and idea upvotes.

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

const MINUTE_MS = 60 * 1000;
const ago = (minutes: number) => new Date(Date.now() - minutes * MINUTE_MS);
const ISO_INSTANT = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/;
const ids = (body: { id: string }[]) => body.map((x) => x.id);

type Auth = { Authorization: string };

function addIdea(id: string, postedAt: Date, extra: Record<string, unknown> = {}) {
  return ForumPostModel.create({
    _id: id,
    authorName: 'Amina T.',
    authorInfo: '4A - Data Science',
    category: 'idea',
    tag: 'Proposition',
    body: 'Des bornes de recharge à la bibliothèque ?',
    postedAt,
    ...extra,
  });
}

const lostKeys = {
  kind: 'lost',
  title: 'Clés Peugeot + Porte-clé ESPRIT',
  category: 'keys',
  zone: 'Parking',
  location: 'Parking Amphi A (Ghazela)',
  place: 'parking',
  distinctiveDetail: 'Boîtier 3 boutons noir',
  reward: 'Café offert ☕',
  isUrgent: true,
};

const foundCalculator = {
  kind: 'found',
  title: 'Calculatrice TI-84 Plus CE',
  category: 'calculator',
  zone: 'Bloc C',
  location: 'Salle C12 (Ghazela)',
  place: 'classroom',
  dropOffNote: "Déposé à l'accueil Bloc C",
  pickupDesk: 'Accueil Bloc C',
};

const publishItem = (auth: Auth, body: object) =>
  request(app).post('/api/forum/lost-items').set(auth).send(body);
const publishIdea = (auth: Auth, body: object) =>
  request(app).post('/api/forum/ideas').set(auth).send(body);
const upvote = (auth: Auth, id: string) =>
  request(app).post(`/api/forum/ideas/${id}/upvote`).set(auth);

describe('authentication', () => {
  test('the publishing routes answer 401 without a valid token', async () => {
    await addIdea('idea-1', ago(5));
    await request(app).post('/api/forum/lost-items').send(lostKeys).expect(401);
    await request(app).get('/api/forum/ideas').expect(401);
    await request(app).post('/api/forum/ideas').send({ body: 'Une idée de test.' }).expect(401);
    await request(app).post('/api/forum/ideas/idea-1/upvote').expect(401);
    await request(app)
      .post('/api/forum/ideas/idea-1/upvote')
      .set({ Authorization: 'Bearer not-a-jwt' })
      .expect(401);

    expect(await LostItemModel.countDocuments()).toBe(0);
    expect(await ForumPostModel.countDocuments()).toBe(1);
    expect(await IdeaVoteModel.countDocuments()).toBe(0);
  });
});

describe('POST /api/forum/lost-items', () => {
  test('publishes a lost item, in the shape of the board', async () => {
    const { user, auth } = await createStudent({ displayName: 'Meriem Ben Ali' });
    const before = Date.now();

    const res = await publishItem(auth, lostKeys).expect(201);

    expect(res.body).toEqual({
      id: expect.stringMatching(/^[0-9a-f]{24}$/),
      kind: 'lost',
      title: 'Clés Peugeot + Porte-clé ESPRIT',
      category: 'keys',
      zone: 'Parking',
      location: 'Parking Amphi A (Ghazela)',
      place: 'parking',
      reporterName: 'Meriem Ben Ali',
      reporterIsStaff: false,
      reportedAt: expect.stringMatching(ISO_INSTANT),
      reference: 'LF-412',
      photoCount: 0,
      isUrgent: true,
      reward: 'Café offert ☕',
      distinctiveDetail: 'Boîtier 3 boutons noir',
      dropOffNote: null,
      pickupDesk: null,
      isSerialHidden: false,
      status: 'active',
      reporterId: user.id,
      isMine: true,
      canManage: true,
    });
    const stored = await LostItemModel.findById(res.body.id).lean();
    expect(stored?.reporterId?.toString()).toBe(user.id);
    expect(stored?.reportedAt.getTime()).toBeGreaterThanOrEqual(before);
    expect(stored?.reportedAt.toISOString()).toBe(res.body.reportedAt);
  });

  test('publishes a found item with its drop-off desk', async () => {
    const { auth } = await createStudent({ displayName: 'Youssef Mrad' });

    const res = await publishItem(auth, foundCalculator).expect(201);

    expect(res.body).toMatchObject({
      kind: 'found',
      reporterName: 'Youssef Mrad',
      reference: 'LF-412',
      isUrgent: false,
      reward: null,
      distinctiveDetail: null,
      dropOffNote: "Déposé à l'accueil Bloc C",
      pickupDesk: 'Accueil Bloc C',
    });
  });

  test('trims the text and stores blank optional fields as null', async () => {
    const { auth } = await createStudent();

    const res = await publishItem(auth, {
      kind: 'found',
      title: '  Gourde isotherme bleue ',
      category: 'bottle',
      zone: ' Cafétéria ',
      location: ' Cafétéria centrale ',
      place: 'cafeteria',
      distinctiveDetail: '   ',
      reward: null,
      isUrgent: false,
      dropOffNote: '',
      pickupDesk: '  Accueil Bloc C  ',
    }).expect(201);

    expect(res.body).toMatchObject({
      title: 'Gourde isotherme bleue',
      zone: 'Cafétéria',
      location: 'Cafétéria centrale',
      distinctiveDetail: null,
      reward: null,
      dropOffNote: null,
      pickupDesk: 'Accueil Bloc C',
    });
  });

  test('each notice gets the next reference, even when published at once', async () => {
    const { auth } = await createStudent();

    const results = await Promise.all([
      publishItem(auth, lostKeys),
      publishItem(auth, foundCalculator),
      publishItem(auth, lostKeys),
    ]);

    expect(results.map((r) => r.status)).toEqual([201, 201, 201]);
    expect(results.map((r) => r.body.reference).sort()).toEqual(['LF-412', 'LF-413', 'LF-414']);
  });

  test('the new notice comes first on the board, for every student', async () => {
    const { auth } = await createStudent();
    const other = await createStudent();
    const demo = await createStudent();
    await seedForum(demo.user._id);

    const res = await publishItem(auth, foundCalculator).expect(201);

    const board = await request(app).get('/api/forum/lost-items').set(other.auth).expect(200);
    expect(board.body).toHaveLength(8);
    // The same notice, but not theirs.
    expect(board.body[0]).toEqual({ ...res.body, isMine: false, canManage: false });
  });

  describe('answers 422 with a French message and stores nothing', () => {
    const cases: [string, object, string][] = [
      ['an empty body', {}, "Indiquez si l'objet est perdu ou trouvé."],
      ['an unknown kind', { ...lostKeys, kind: 'stolen' }, "Indiquez si l'objet est perdu ou trouvé."],
      [
        'a missing title',
        { ...lostKeys, title: undefined },
        "Donnez un titre à l'annonce (ex : Calculatrice TI-84).",
      ],
      [
        'a blank title',
        { ...lostKeys, title: '  ' },
        "Donnez un titre à l'annonce (ex : Calculatrice TI-84).",
      ],
      [
        'a title too long',
        { ...lostKeys, title: 'x'.repeat(81) },
        'Le titre ne doit pas dépasser 80 caractères.',
      ],
      ['an unknown category', { ...lostKeys, category: 'laptop' }, "Choisissez une catégorie d'objet."],
      ['a missing zone', { ...lostKeys, zone: '' }, 'Indiquez la zone (ex : Bloc C).'],
      ['a missing location', { ...lostKeys, location: null }, 'Précisez le lieu (ex : Salle C12).'],
      ['an unknown place', { ...lostKeys, place: 'gym' }, 'Choisissez le type de lieu.'],
      [
        'a detail that is not text',
        { ...lostKeys, distinctiveDetail: 42 },
        'Le détail distinctif doit être un texte.',
      ],
      [
        'a reward too long',
        { ...lostKeys, reward: 'x'.repeat(61) },
        'La récompense ne doit pas dépasser 60 caractères.',
      ],
      [
        'an urgent flag that is not a boolean',
        { ...lostKeys, isUrgent: 'yes' },
        'Indiquez si la recherche est urgente (oui ou non).',
      ],
      [
        'a found item without drop-off',
        { ...foundCalculator, dropOffNote: ' ', pickupDesk: null },
        "Indiquez où l'objet a été déposé (ex : Accueil Bloc C).",
      ],
      [
        'a found item with a reward',
        { ...foundCalculator, reward: 'Café offert' },
        'Une récompense concerne uniquement les objets perdus.',
      ],
      [
        'an urgent found item',
        { ...foundCalculator, isUrgent: true },
        'Seul un objet perdu peut être marqué urgent.',
      ],
      [
        'a lost item with a drop-off desk',
        { ...lostKeys, pickupDesk: 'Accueil Bloc C' },
        'Le lieu de dépôt concerne uniquement les objets trouvés.',
      ],
    ];

    test.each(cases)('%s', async (_name, body, message) => {
      const { auth } = await createStudent();
      await publishItem(auth, body).expect(422, validationError(message));
      expect(await LostItemModel.countDocuments()).toBe(0);
    });
  });
});

describe('POST /api/forum/ideas', () => {
  test('publishes an idea by the student, with no votes yet', async () => {
    const { user, auth } = await createStudent({ displayName: 'Dony Mansour' });
    const before = Date.now();

    const res = await publishIdea(auth, {
      body: '  Un distributeur de boissons chaudes au Bloc E ?  ',
    }).expect(201);

    expect(res.body).toEqual({
      id: expect.stringMatching(/^[0-9a-f]{24}$/),
      authorName: 'Dony Mansour',
      authorInfo: 'Étudiant ESPRIT',
      category: 'idea',
      tag: 'Proposition',
      body: 'Un distributeur de boissons chaudes au Bloc E ?',
      place: null,
      upvotes: 0,
      comments: 0,
      status: null,
      postedAt: expect.stringMatching(ISO_INSTANT),
      isUpvotedByMe: false,
    });
    const stored = await ForumPostModel.findById(res.body.id).lean();
    expect(stored?.authorId?.toString()).toBe(user.id);
    expect(stored?.postedAt.getTime()).toBeGreaterThanOrEqual(before);
  });

  test("shows the student's class and program when the school set a profile", async () => {
    const { user, auth } = await createStudent();
    await StudentProfileModel.create({
      userId: user._id,
      yearOfStudy: 4,
      classGroup: 'BI',
      program: 'Software Engineering',
      programShort: 'Software Eng.',
    });

    const res = await publishIdea(auth, { body: 'Un club de robotique ouvert à tous.' });

    expect(res.status).toBe(201);
    expect(res.body.authorInfo).toBe('4BI - Software Eng.');
  });

  test('keeps a theme as the badge, trimmed', async () => {
    const { auth } = await createStudent();
    const res = await publishIdea(auth, {
      body: 'Une journée portes ouvertes des clubs.',
      tag: ' Vie de campus ',
    }).expect(201);
    expect(res.body.tag).toBe('Vie de campus');

    const blank = await publishIdea(auth, { body: 'Plus de prises au foyer.', tag: '' });
    expect(blank.body.tag).toBe('Proposition');
  });

  test('the new idea shows in the ideas and in the Home highlights', async () => {
    const { auth } = await createStudent();
    const other = await createStudent();
    await addIdea('idea-old', ago(60));

    const res = await publishIdea(auth, { body: 'Un distributeur au Bloc E ?' }).expect(201);

    const ideas = await request(app).get('/api/forum/ideas').set(other.auth).expect(200);
    expect(ids(ideas.body)).toEqual([res.body.id, 'idea-old']);
    const highlights = await request(app).get('/api/forum/highlights').set(other.auth).expect(200);
    expect(highlights.body[0]).toEqual(res.body);
  });

  test('answers 401 for a valid token of a deleted account', async () => {
    const { user, auth } = await createStudent();
    await user.deleteOne();
    await publishIdea(auth, { body: 'Une idée sans auteur.' }).expect(401);
    await publishItem(auth, lostKeys).expect(401);
    expect(await ForumPostModel.countDocuments()).toBe(0);
    expect(await LostItemModel.countDocuments()).toBe(0);
  });

  describe('answers 422 with a French message and stores nothing', () => {
    const cases: [string, object, string][] = [
      ['an empty body', {}, 'Décrivez votre idée.'],
      ['a blank idea', { body: ' \n ' }, 'Décrivez votre idée.'],
      ['an idea that is not text', { body: 42 }, 'Décrivez votre idée.'],
      [
        'an idea too short',
        { body: 'Wifi ?' },
        'Votre idée est trop courte : 10 caractères minimum.',
      ],
      [
        'an idea too long',
        { body: 'x'.repeat(501) },
        'Votre idée ne doit pas dépasser 500 caractères.',
      ],
      [
        'a theme too long',
        { body: 'Une idée assez longue.', tag: 'x'.repeat(25) },
        'Le thème ne doit pas dépasser 24 caractères.',
      ],
      [
        'a theme that is not text',
        { body: 'Une idée assez longue.', tag: ['a'] },
        'Le thème doit être un texte.',
      ],
    ];

    test.each(cases)('%s', async (_name, body, message) => {
      const { auth } = await createStudent();
      await publishIdea(auth, body).expect(422, validationError(message));
      expect(await ForumPostModel.countDocuments()).toBe(0);
    });
  });
});

describe('GET /api/forum/ideas', () => {
  test('lists only the ideas, most upvoted first, then newest', async () => {
    const { auth } = await createStudent();
    await addIdea('idea-popular', ago(300), { upvotes: 42, comments: 8, status: 'En examen BDE' });
    await addIdea('idea-new', ago(5));
    await addIdea('idea-old', ago(120));
    await addIdea('idea-liked', ago(200), { upvotes: 3 });
    await ForumPostModel.create({
      _id: 'post-carpool',
      authorName: 'Sarra K.',
      authorInfo: '5A - Informatique',
      category: 'carpool',
      tag: '2 places',
      body: 'Départ à 13h15',
      postedAt: ago(1),
    });

    const res = await request(app).get('/api/forum/ideas').set(auth).expect(200);

    expect(ids(res.body)).toEqual(['idea-popular', 'idea-liked', 'idea-new', 'idea-old']);
    expect(res.body[0]).toEqual({
      id: 'idea-popular',
      authorName: 'Amina T.',
      authorInfo: '4A - Data Science',
      category: 'idea',
      tag: 'Proposition',
      body: 'Des bornes de recharge à la bibliothèque ?',
      place: null,
      upvotes: 42,
      comments: 8,
      status: 'En examen BDE',
      postedAt: expect.stringMatching(ISO_INSTANT),
      isUpvotedByMe: false,
    });
  });

  test("students' votes add to the seeded count and change the order", async () => {
    const students = await Promise.all([createStudent(), createStudent(), createStudent()]);
    await addIdea('idea-seeded', ago(300), { upvotes: 1 });
    await addIdea('idea-new', ago(5));

    for (const { auth } of students.slice(0, 2)) await upvote(auth, 'idea-new').expect(200);

    const res = await request(app).get('/api/forum/ideas').set(students[0].auth).expect(200);
    expect(res.body.map((i: { id: string; upvotes: number }) => [i.id, i.upvotes])).toEqual([
      ['idea-new', 2],
      ['idea-seeded', 1],
    ]);
  });

  test('is an empty list when there are no ideas', async () => {
    const { auth } = await createStudent();
    await request(app).get('/api/forum/ideas').set(auth).expect(200, []);
  });
});

describe('POST /api/forum/ideas/:id/upvote', () => {
  test('toggles the vote of the student', async () => {
    const { user, auth } = await createStudent();
    await addIdea('post-3', ago(120), { upvotes: 42 });

    await upvote(auth, 'post-3').expect(200, { upvotes: 43, isUpvotedByMe: true });
    const vote = await IdeaVoteModel.findOne({ ideaId: 'post-3' }).lean();
    expect(vote?.userId.toString()).toBe(user.id);

    await upvote(auth, 'post-3').expect(200, { upvotes: 42, isUpvotedByMe: false });
    expect(await IdeaVoteModel.countDocuments()).toBe(0);

    await upvote(auth, 'post-3').expect(200, { upvotes: 43, isUpvotedByMe: true });
  });

  test("keeps one vote per student, separate from other students' votes", async () => {
    const first = await createStudent();
    const second = await createStudent();
    const reader = await createStudent();
    await addIdea('post-3', ago(120), { upvotes: 42 });

    await upvote(first.auth, 'post-3').expect(200, { upvotes: 43, isUpvotedByMe: true });
    await upvote(second.auth, 'post-3').expect(200, { upvotes: 44, isUpvotedByMe: true });

    const seenBy = async (auth: Auth) =>
      (await request(app).get('/api/forum/ideas').set(auth).expect(200)).body[0];
    expect(await seenBy(first.auth)).toMatchObject({ upvotes: 44, isUpvotedByMe: true });
    expect(await seenBy(second.auth)).toMatchObject({ upvotes: 44, isUpvotedByMe: true });
    expect(await seenBy(reader.auth)).toMatchObject({ upvotes: 44, isUpvotedByMe: false });

    // The first student takes their vote back: the second one's stays.
    await upvote(first.auth, 'post-3').expect(200, { upvotes: 43, isUpvotedByMe: false });
    expect(await seenBy(first.auth)).toMatchObject({ upvotes: 43, isUpvotedByMe: false });
    expect(await seenBy(second.auth)).toMatchObject({ upvotes: 43, isUpvotedByMe: true });
  });

  test('two taps at once never store two votes for a student', async () => {
    const { auth } = await createStudent();
    await addIdea('post-3', ago(120), { upvotes: 42 });

    const results = await Promise.all([upvote(auth, 'post-3'), upvote(auth, 'post-3')]);

    expect(results.map((r) => r.status)).toEqual([200, 200]);
    const votes = await IdeaVoteModel.countDocuments({ ideaId: 'post-3' });
    expect(votes).toBeLessThanOrEqual(1);
    const ideas = await request(app).get('/api/forum/ideas').set(auth).expect(200);
    expect(ideas.body[0]).toMatchObject({ upvotes: 42 + votes, isUpvotedByMe: votes === 1 });
  });

  test('answers 404 for an unknown idea or a post of another section', async () => {
    const { auth } = await createStudent();
    await ForumPostModel.create({
      _id: 'post-1',
      authorName: 'Sarra K.',
      authorInfo: '5A - Informatique',
      category: 'carpool',
      tag: '2 places',
      body: 'Départ à 13h15',
      postedAt: ago(12),
    });

    const gone = { message: "Cette idée n'existe plus." };
    await upvote(auth, 'idea-000').expect(404, gone);
    await upvote(auth, 'post-1').expect(404, gone);
    expect(await IdeaVoteModel.countDocuments()).toBe(0);
  });
});

describe('GET /api/forum/highlights', () => {
  test("shows each student's own vote on the ideas", async () => {
    const voter = await createStudent();
    const reader = await createStudent();
    const demo = await createStudent();
    await seedForum(demo.user._id);
    await upvote(voter.auth, 'post-3').expect(200);

    const seenBy = async (auth: Auth) => {
      const res = await request(app).get('/api/forum/highlights').set(auth).expect(200);
      return res.body.map((p: { id: string; upvotes: number; isUpvotedByMe: boolean }) => [
        p.id,
        p.upvotes,
        p.isUpvotedByMe,
      ]);
    };
    expect(await seenBy(voter.auth)).toEqual([
      ['post-1', 0, false],
      ['post-2', 0, false],
      ['post-3', 43, true],
    ]);
    expect(await seenBy(reader.auth)).toEqual([
      ['post-1', 0, false],
      ['post-2', 0, false],
      ['post-3', 43, false],
    ]);
  });
});

describe('seedForum', () => {
  test('keeps the published content and real votes, and resets the demo votes', async () => {
    const demo = await createStudent();
    const other = await createStudent();
    await seedForum(demo.user._id);
    const item = await publishItem(other.auth, foundCalculator).expect(201);
    const idea = await publishIdea(other.auth, { body: 'Un distributeur au Bloc E ?' }).expect(201);
    for (const { auth } of [demo, other]) await upvote(auth, 'post-3').expect(200);

    await seedForum(demo.user._id);

    expect(await LostItemModel.exists({ _id: item.body.id })).toBeTruthy();
    expect(await ForumPostModel.exists({ _id: idea.body.id })).toBeTruthy();
    const ideas = await request(app).get('/api/forum/ideas').set(demo.auth).expect(200);
    expect(ideas.body[0]).toMatchObject({ id: 'post-3', upvotes: 43, isUpvotedByMe: false });

    // The demo student can show the upvote again.
    await upvote(demo.auth, 'post-3').expect(200, { upvotes: 44, isUpvotedByMe: true });
  });
});
