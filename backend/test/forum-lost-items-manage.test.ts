import request from 'supertest';

import { createApp } from '../src/app';
import { LostItemModel } from '../src/modules/forum/lost-item.model';
import { LostItemRequestModel } from '../src/modules/forum/lost-item-request.model';
import {
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  validationError,
} from './helpers';

// Managing a Lost & Found notice: edit, resolve, delete (its reporter or an admin).

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

type Auth = { Authorization: string };

const NOT_YOURS = {
  message: "Seul l'auteur de l'annonce (ou un administrateur) peut la modifier ou la supprimer.",
};
const GONE = { message: "Cette annonce n'existe plus." };

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

async function publish(auth: Auth, body: object = lostKeys): Promise<{ id: string }> {
  const res = await request(app).post('/api/forum/lost-items').set(auth).send(body).expect(201);
  return res.body as { id: string };
}

const patch = (auth: Auth, id: string, body: object) =>
  request(app).patch(`/api/forum/lost-items/${id}`).set(auth).send(body);
const remove = (auth: Auth, id: string) =>
  request(app).delete(`/api/forum/lost-items/${id}`).set(auth);
const board = async (auth: Auth) =>
  (await request(app).get('/api/forum/lost-items').set(auth).expect(200)).body as {
    id: string;
    [key: string]: unknown;
  }[];

/** A demo notice reported an hour ago (before the ones published by the tests), no reporter account. */
const addDeskItem = (id: string) =>
  LostItemModel.create({
    _id: id,
    kind: 'found',
    title: 'Gourde isotherme bleue',
    category: 'bottle',
    zone: 'Cafétéria',
    location: 'Cafétéria centrale (Ghazela)',
    place: 'cafeteria',
    reporterName: 'Agent de sécurité',
    reporterIsStaff: true,
    reportedAt: new Date(Date.now() - 60 * 60 * 1000),
    pickupDesk: 'Accueil Bloc C',
  });

describe('authentication', () => {
  test('the new routes answer 401 without a valid token', async () => {
    await addDeskItem('lf-402');
    await request(app).patch('/api/forum/lost-items/lf-402').send({ status: 'resolved' }).expect(401);
    await request(app).delete('/api/forum/lost-items/lf-402').expect(401);
    await request(app).get('/api/forum/lost-items/lf-402/matches').expect(401);
  });
});

describe('GET /api/forum/lost-items: isMine and canManage', () => {
  test('are the viewer’s: the reporter and admins can manage, others cannot', async () => {
    const reporter = await createStudent();
    const other = await createStudent();
    const admin = await createAdmin();
    const { id } = await publish(reporter.auth);
    await addDeskItem('lf-402');

    const seen = async (auth: Auth) =>
      (await board(auth)).map((i) => [i.id, i.isMine, i.canManage, i.status]);
    expect(await seen(reporter.auth)).toEqual([
      [id, true, true, 'active'],
      ['lf-402', false, false, 'active'],
    ]);
    expect(await seen(other.auth)).toEqual([
      [id, false, false, 'active'],
      ['lf-402', false, false, 'active'],
    ]);
    expect(await seen(admin.auth)).toEqual([
      [id, false, true, 'active'],
      ['lf-402', false, true, 'active'],
    ]);
  });

  test('an item saved before statuses existed is active', async () => {
    const { auth } = await createStudent();
    await addDeskItem('lf-402');
    await LostItemModel.collection.updateOne({ _id: 'lf-402' as never }, { $unset: { status: 1 } });
    expect((await board(auth))[0].status).toBe('active');
  });
});

describe('PATCH /api/forum/lost-items/:id', () => {
  test('the reporter edits: sent fields replace, null clears, the rest is kept', async () => {
    const { auth, user } = await createStudent();
    const { id } = await publish(auth);

    const res = await patch(auth, id, { title: '  Clés Renault  ', reward: null }).expect(200);

    expect(res.body).toMatchObject({
      id,
      title: 'Clés Renault',
      reward: null,
      isUrgent: true,
      distinctiveDetail: 'Boîtier 3 boutons noir',
      zone: 'Parking',
      reference: 'LF-412',
      status: 'active',
      reporterId: user.id,
      isMine: true,
      canManage: true,
    });
    expect((await board(auth))[0]).toEqual(res.body);
  });

  test('marks a notice resolved, and active again', async () => {
    const { auth } = await createStudent();
    const { id } = await publish(auth);

    const resolved = await patch(auth, id, { status: 'resolved' }).expect(200);
    expect(resolved.body).toMatchObject({ status: 'resolved', title: lostKeys.title });
    expect((await LostItemModel.findById(id).lean())?.status).toBe('resolved');

    await patch(auth, id, { status: 'active' }).expect(200);
    expect((await board(auth))[0].status).toBe('active');
  });

  test('a resolved notice refuses new requests (409)', async () => {
    const reporter = await createStudent();
    const finder = await createStudent();
    const { id } = await publish(reporter.auth);
    await patch(reporter.auth, id, { status: 'resolved' }).expect(200);

    await request(app)
      .post(`/api/forum/lost-items/${id}/requests`)
      .set(finder.auth)
      .send({ proof: 'Boîtier noir' })
      .expect(409, { message: 'This item was already returned to its owner.' });
  });

  test('switching the kind drops the other kind’s fields, and checks the notice whole', async () => {
    const { auth } = await createStudent();
    const { id } = await publish(auth);

    await patch(auth, id, { kind: 'found' }).expect(
      422,
      validationError("Indiquez où l'objet a été déposé (ex : Accueil Bloc C)."),
    );
    const res = await patch(auth, id, { kind: 'found', pickupDesk: 'Accueil Bloc C' }).expect(200);
    expect(res.body).toMatchObject({
      kind: 'found',
      reward: null,
      isUrgent: false,
      pickupDesk: 'Accueil Bloc C',
      distinctiveDetail: 'Boîtier 3 boutons noir',
    });
  });

  test('refuses invalid edits with 422, and stores nothing', async () => {
    const { auth } = await createStudent();
    const { id } = await publish(auth);
    const found = await publish(auth, {
      kind: 'found',
      title: 'Parapluie noir',
      category: 'other',
      zone: 'Bibliothèque',
      location: 'Bibliothèque centrale (Étage 1)',
      place: 'library',
      pickupDesk: 'Accueil Bloc C',
    });

    await patch(auth, id, {}).expect(
      422,
      validationError('Rien à modifier : envoyez au moins un champ.'),
    );
    await patch(auth, id, { title: '   ' }).expect(
      422,
      validationError("Donnez un titre à l'annonce (ex : Calculatrice TI-84)."),
    );
    await patch(auth, id, { title: 'x'.repeat(81) }).expect(
      422,
      validationError('Le titre ne doit pas dépasser 80 caractères.'),
    );
    await patch(auth, id, { status: 'closed' }).expect(
      422,
      validationError('Le statut doit être « active » ou « resolved ».'),
    );
    await patch(auth, found.id, { reward: 'Un café' }).expect(
      422,
      validationError('Une récompense concerne uniquement les objets perdus.'),
    );

    const stored = await LostItemModel.findById(id).lean();
    expect(stored).toMatchObject({ title: lostKeys.title, kind: 'lost', status: 'active' });
  });

  test('another student gets 403; an admin may edit any notice', async () => {
    const reporter = await createStudent();
    const other = await createStudent();
    const admin = await createAdmin();
    const { id } = await publish(reporter.auth);

    await patch(other.auth, id, { status: 'resolved' }).expect(403, NOT_YOURS);
    expect((await LostItemModel.findById(id).lean())?.status).toBe('active');

    const res = await patch(admin.auth, id, { status: 'resolved' }).expect(200);
    expect(res.body).toMatchObject({ status: 'resolved', isMine: false, canManage: true });
  });

  test('a notice without a reporter account can only be managed by an admin', async () => {
    const student = await createStudent();
    const admin = await createAdmin();
    await addDeskItem('lf-402');

    await patch(student.auth, 'lf-402', { title: 'Gourde verte' }).expect(403, NOT_YOURS);
    const res = await patch(admin.auth, 'lf-402', { title: 'Gourde verte' }).expect(200);
    expect(res.body).toMatchObject({ title: 'Gourde verte', reporterId: null });
  });

  test('404 for an unknown notice', async () => {
    const { auth } = await createStudent();
    await patch(auth, 'lf-000', { status: 'resolved' }).expect(404, GONE);
  });
});

describe('DELETE /api/forum/lost-items/:id', () => {
  test('the reporter deletes a notice, with the requests about it', async () => {
    const reporter = await createStudent();
    const finder = await createStudent();
    const { id } = await publish(reporter.auth);
    await request(app)
      .post(`/api/forum/lost-items/${id}/requests`)
      .set(finder.auth)
      .send({ proof: 'Boîtier noir' })
      .expect(201);

    await remove(reporter.auth, id).expect(204);

    expect(await board(reporter.auth)).toEqual([]);
    expect(await LostItemRequestModel.countDocuments({ itemId: id })).toBe(0);
    await remove(reporter.auth, id).expect(404, GONE);
  });

  test('another student gets 403; an admin may delete any notice', async () => {
    const reporter = await createStudent();
    const other = await createStudent();
    const admin = await createAdmin();
    const { id } = await publish(reporter.auth);
    await addDeskItem('lf-402');

    await remove(other.auth, id).expect(403, NOT_YOURS);
    await remove(other.auth, 'lf-402').expect(403, NOT_YOURS);
    expect(await LostItemModel.countDocuments()).toBe(2);

    await remove(admin.auth, id).expect(204);
    await remove(admin.auth, 'lf-402').expect(204);
    expect(await LostItemModel.countDocuments()).toBe(0);
  });

  test('404 for an unknown notice', async () => {
    const { auth } = await createStudent();
    await remove(auth, 'lf-000').expect(404, GONE);
  });
});
