import request from 'supertest';
import { Types } from 'mongoose';

import { createApp } from '../src/app';
import { atCampusTime, campusMonth } from '../src/modules/carpool/campus-time';
import { RideModel } from '../src/modules/carpool/carpool.model';
import { seedCarpool } from '../src/modules/carpool/carpool.seed';
import { clearTestDb, closeTestDb, connectTestDb, createStudent, validationError } from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

// 11:00 in Tunis (UTC+1).
const SEED_TIME = new Date('2026-11-06T10:00:00.000Z');

interface SeatBody {
  id: string;
  label: string;
  status: string;
}
interface RideBody {
  id: string;
  departure: string;
  arrival: string;
  seats: SeatBody[];
}

const seed = (now = SEED_TIME) => seedCarpool(new Types.ObjectId(), now);
const seatsOf = (ride: RideBody) => ride.seats.map((s) => `${s.id}:${s.status}:${s.label}`);

describe('campus time', () => {
  test('resolves wall-clock times in Tunis (UTC+1)', () => {
    expect(atCampusTime(SEED_TIME, 0, 13, 15).toISOString()).toBe('2026-11-06T12:15:00.000Z');
    expect(atCampusTime(SEED_TIME, 1, 8, 0).toISOString()).toBe('2026-11-07T07:00:00.000Z');
    expect(campusMonth(SEED_TIME)).toBe('2026-11');
  });

  test('uses the Tunis day, which starts one hour before the UTC one', () => {
    const justAfterMidnightInTunis = new Date('2026-11-30T23:30:00.000Z');
    expect(atCampusTime(justAfterMidnightInTunis, 0, 13, 15).toISOString()).toBe(
      '2026-12-01T12:15:00.000Z',
    );
    expect(campusMonth(justAfterMidnightInTunis)).toBe('2026-12');
  });
});

describe('every carpool route needs a token', () => {
  test.each([
    ['get', '/api/carpool/rides'],
    ['post', '/api/carpool/rides'],
    ['get', '/api/carpool/rides/es-4091'],
    ['post', '/api/carpool/rides/es-4091/reservations'],
  ] as const)('%s %s answers 401', async (method, path) => {
    const res = await request(app)[method](path).send({ seatIds: ['s3'] }).expect(401);
    expect(res.body).toEqual({ message: 'Invalid credentials or expired session.' });
  });
});

describe('GET /api/carpool/rides', () => {
  test('returns the seeded demo rides, soonest first', async () => {
    await seed();
    const { auth } = await createStudent();

    const res = await request(app).get('/api/carpool/rides').set(auth).expect(200);
    const rides = res.body as RideBody[];

    expect(rides.map((r) => r.id)).toEqual(['es-4091', 'es-4093', 'es-4092']);
    expect(rides[0]).toEqual({
      id: 'es-4091',
      code: 'ES-4091',
      pickup: 'Tunis Centre (Passage)',
      dropoff: 'ESPRIT Ghazela (Bloc H)',
      pickupTag: 'Passage',
      dropoffTag: 'ESPRIT Bloc H',
      dropoffNote: 'Drop-off direct at Bloc H (Ghazela Technopark)',
      departure: '2026-11-06T12:15:00.000Z',
      arrival: '2026-11-06T12:45:00.000Z',
      distanceKm: 14.2,
      pricePerSeat: 2.5,
      driver: {
        name: 'Sarra K.',
        rating: 4.9,
        profile: '4th Year Telecom Engineering student',
        ridesCompleted: 38,
        carModel: 'Renault Clio 4',
        carColor: 'White',
        plate: '218 · TN · 9812',
        isCarVerified: true,
      },
      seats: [
        { id: 's1', label: 'Sarra K.', status: 'driver' },
        { id: 's2', label: 'Ahmed D.', status: 'booked' },
        { id: 's3', label: 'Seat #3', status: 'free' },
        { id: 's4', label: 'Seat #4', status: 'free' },
      ],
      amenities: ['nonSmoking', 'airConditioned', 'musicOk'],
      isMine: false,
    });
    expect(rides[1]).toMatchObject({
      id: 'es-4093',
      departure: '2026-11-06T16:30:00.000Z',
      arrival: '2026-11-06T17:05:00.000Z',
      amenities: ['airConditioned', 'musicOk'],
    });
    expect(seatsOf(rides[1])).toEqual([
      's1:driver:Kenza B.',
      's2:booked:Rami T.',
      's3:booked:Lina S.',
      's4:free:Seat #4',
    ]);
    expect(rides[2]).toMatchObject({
      id: 'es-4092',
      departure: '2026-11-07T07:00:00.000Z',
      arrival: '2026-11-07T07:25:00.000Z',
      pricePerSeat: 2,
      amenities: ['nonSmoking', 'airConditioned'],
    });
    expect(seatsOf(rides[2])).toEqual([
      's1:driver:Youssef M.',
      's2:free:Seat #2',
      's3:free:Seat #3',
      's4:free:Seat #4',
    ]);
  });

  test('is empty before the seed', async () => {
    const { auth } = await createStudent();
    await request(app).get('/api/carpool/rides').set(auth).expect(200, []);
  });
});

describe('GET /api/carpool/rides/:id', () => {
  test('returns one ride', async () => {
    await seed();
    const { auth } = await createStudent();
    const res = await request(app).get('/api/carpool/rides/es-4092').set(auth).expect(200);
    expect(res.body).toMatchObject({ id: 'es-4092', code: 'ES-4092', distanceKm: 9.6 });
  });

  test('answers 404 for an unknown ride', async () => {
    await seed();
    const { auth } = await createStudent();
    const res = await request(app).get('/api/carpool/rides/es-0000').set(auth).expect(404);
    expect(res.body).toEqual({ message: 'Ride not found.' });
  });
});

describe('POST /api/carpool/rides/:id/reservations', () => {
  const reserve = (auth: { Authorization: string }, seatIds: unknown, rideId = 'es-4091') =>
    request(app).post(`/api/carpool/rides/${rideId}/reservations`).set(auth).send({ seatIds });

  test('books the seats and answers 201 with the updated ride', async () => {
    await seed();
    const { auth } = await createStudent();

    const res = await reserve(auth, ['s3', 's4']).expect(201);

    expect(seatsOf(res.body as RideBody)).toEqual([
      's1:driver:Sarra K.',
      's2:booked:Ahmed D.',
      's3:booked:You',
      's4:booked:You',
    ]);
    const again = await request(app).get('/api/carpool/rides/es-4091').set(auth).expect(200);
    expect(again.body).toEqual(res.body);
  });

  test('shows "You" only to the student who booked, and their name to the others', async () => {
    await seed();
    const sarra = await createStudent({ displayName: 'Sarra Kefi' });
    const omar = await createStudent({ displayName: 'Omar Ben Salah' });
    await reserve(sarra.auth, ['s3']).expect(201);
    await reserve(omar.auth, ['s4']).expect(201);

    const seenBySarra = await request(app).get('/api/carpool/rides').set(sarra.auth).expect(200);
    const seenByOmar = await request(app).get('/api/carpool/rides').set(omar.auth).expect(200);
    const newcomer = await createStudent();
    const seenByNewcomer = await request(app)
      .get('/api/carpool/rides/es-4091')
      .set(newcomer.auth)
      .expect(200);

    expect(seatsOf((seenBySarra.body as RideBody[])[0]).slice(2)).toEqual([
      's3:booked:You',
      's4:booked:Omar Ben Salah',
    ]);
    expect(seatsOf((seenByOmar.body as RideBody[])[0]).slice(2)).toEqual([
      's3:booked:Sarra Kefi',
      's4:booked:You',
    ]);
    expect(seatsOf(seenByNewcomer.body as RideBody).slice(2)).toEqual([
      's3:booked:Sarra Kefi',
      's4:booked:Omar Ben Salah',
    ]);
  });

  test('answers 409 when a seat is booked, the driver\'s or unknown', async () => {
    await seed();
    const { auth } = await createStudent();
    for (const seatIds of [['s2'], ['s1'], ['s9']]) {
      const res = await reserve(auth, seatIds).expect(409);
      expect(res.body).toEqual({ message: 'This seat is no longer available.' });
    }
  });

  test('books nothing when one of the seats is taken (all or nothing)', async () => {
    await seed();
    const { auth } = await createStudent();
    await reserve(auth, ['s3', 's2']).expect(409);

    const ride = await request(app).get('/api/carpool/rides/es-4091').set(auth).expect(200);
    expect(seatsOf(ride.body as RideBody)[2]).toBe('s3:free:Seat #3');
  });

  test('gives a seat to exactly one of two students booking it at the same time', async () => {
    await seed();
    const first = await createStudent({ displayName: 'First Student' });
    const second = await createStudent({ displayName: 'Second Student' });

    const results = await Promise.all([reserve(first.auth, ['s3']), reserve(second.auth, ['s3'])]);

    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    const loser = results.find((r) => r.status === 409);
    expect(loser?.body).toEqual({ message: 'This seat is no longer available.' });
    const ride = await RideModel.findById('es-4091');
    expect(ride?.seats[2]?.status).toBe('booked');
  });

  test('answers 422 without seats', async () => {
    await seed();
    const { auth } = await createStudent();

    const empty = await reserve(auth, []).expect(422);
    expect(empty.body).toEqual(validationError('Choose at least one seat'));

    const missing = await request(app)
      .post('/api/carpool/rides/es-4091/reservations')
      .set(auth)
      .send({})
      .expect(422);
    expect(missing.body).toEqual(validationError('Choose at least one seat'));

    const blank = await reserve(auth, ['  ']).expect(422);
    expect(blank.body).toEqual(validationError('Choose a valid seat'));
  });

  test('answers 404 for an unknown ride', async () => {
    await seed();
    const { auth } = await createStudent();
    const res = await reserve(auth, ['s3'], 'es-0000').expect(404);
    expect(res.body).toEqual({ message: 'Ride not found.' });
  });
});

describe('seedCarpool', () => {
  test('is idempotent, moves the rides to the new day and drops old bookings', async () => {
    await seed();
    const { auth } = await createStudent();
    await request(app)
      .post('/api/carpool/rides/es-4091/reservations')
      .set(auth)
      .send({ seatIds: ['s3'] })
      .expect(201);

    await seed(new Date('2026-11-09T10:00:00.000Z'));

    expect(await RideModel.countDocuments()).toBe(3);
    const res = await request(app).get('/api/carpool/rides/es-4091').set(auth).expect(200);
    const ride = res.body as RideBody;
    expect(ride.departure).toBe('2026-11-09T12:15:00.000Z');
    expect(seatsOf(ride)[2]).toBe('s3:free:Seat #3');
  });
});
