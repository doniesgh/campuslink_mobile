import request from 'supertest';
import { Types } from 'mongoose';

import { createApp } from '../src/app';
import { RideCounterModel, RideModel } from '../src/modules/carpool/carpool.model';
import { seedCarpool } from '../src/modules/carpool/carpool.seed';
import { StudentProfileModel } from '../src/modules/profile/profile.model';
import { clearTestDb, closeTestDb, connectTestDb, createStudent } from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

type Auth = { Authorization: string };

interface SeatBody {
  id: string;
  label: string;
  status: string;
}
interface RideBody {
  id: string;
  code: string;
  seats: SeatBody[];
  isMine: boolean;
  driver: { name: string; rating: number; ridesCompleted: number; profile: string };
}

const MINUTE = 60 * 1000;
const DAY = 24 * 60 * MINUTE;

/** A valid ride leaving tomorrow (the departure must be in the future). */
function rideBody(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  const departure = new Date(Date.now() + DAY);
  return {
    pickup: '  Lac 2 (Tunis City)  ',
    pickupTag: 'Lac 2',
    dropoff: 'ESPRIT Ghazela (Bloc E)',
    dropoffTag: 'ESPRIT Bloc E',
    departure: departure.toISOString(),
    arrival: new Date(departure.getTime() + 35 * MINUTE).toISOString(),
    seatCount: 3,
    pricePerSeat: 2.5,
    carModel: 'Volkswagen Polo',
    carColor: 'Blue',
    plate: '231 TN 1187',
    amenities: ['nonSmoking', 'musicOk', 'nonSmoking'],
    dropoffNote: 'Drop-off at the Bloc E parking',
    distanceKm: 12.4,
    ...overrides,
  };
}

const publish = (auth: Auth, body: unknown = rideBody()) =>
  request(app).post('/api/carpool/rides').set(auth).send(body as object);

const seatsOf = (ride: RideBody) => ride.seats.map((s) => `${s.id}:${s.status}:${s.label}`);

describe('POST /api/carpool/rides', () => {
  test('answers 401 without a token', async () => {
    const res = await request(app).post('/api/carpool/rides').send(rideBody()).expect(401);
    expect(res.body).toEqual({ message: 'Invalid credentials or expired session.' });
    expect(await RideModel.countDocuments()).toBe(0);
  });

  test('publishes the ride and answers 201 with it, in the shape of GET /rides/:id', async () => {
    const { auth } = await createStudent({ displayName: 'Dony Mansour' });
    const body = rideBody();

    const res = await publish(auth, body).expect(201);

    expect(res.body).toEqual({
      id: 'es-4094',
      code: 'ES-4094',
      pickup: 'Lac 2 (Tunis City)',
      dropoff: 'ESPRIT Ghazela (Bloc E)',
      pickupTag: 'Lac 2',
      dropoffTag: 'ESPRIT Bloc E',
      dropoffNote: 'Drop-off at the Bloc E parking',
      departure: body.departure,
      arrival: body.arrival,
      distanceKm: 12.4,
      pricePerSeat: 2.5,
      driver: {
        name: 'Dony Mansour',
        // No rating system yet: a new driver, shown as such by the app.
        rating: 0,
        profile: 'ESPRIT student',
        ridesCompleted: 0,
        carModel: 'Volkswagen Polo',
        carColor: 'Blue',
        plate: '231 TN 1187',
        isCarVerified: false,
      },
      seats: [
        { id: 's1', label: 'Dony Mansour', status: 'driver' },
        { id: 's2', label: 'Seat #2', status: 'free' },
        { id: 's3', label: 'Seat #3', status: 'free' },
        { id: 's4', label: 'Seat #4', status: 'free' },
      ],
      amenities: ['nonSmoking', 'musicOk'],
      isMine: true,
    });
    const again = await request(app).get('/api/carpool/rides/es-4094').set(auth).expect(200);
    expect(again.body).toEqual(res.body);
  });

  test("stores the driver's user id on the ride", async () => {
    await seedCarpool(new Types.ObjectId());
    const { user, auth } = await createStudent();

    const res = await publish(auth).expect(201);

    const stored = await RideModel.findById((res.body as RideBody).id);
    expect(stored?.driverId?.equals(user._id)).toBe(true);
    // The demo rides have no driver account.
    expect(await RideModel.countDocuments({ driverId: null })).toBe(3);
    expect(await RideModel.exists({ driverId: user._id })).not.toBeNull();
  });

  test("describes the driver from their profile when the school set one", async () => {
    const { user, auth } = await createStudent();
    await StudentProfileModel.create({
      userId: user._id,
      yearOfStudy: 4,
      program: 'Software Engineering',
    });

    const res = await publish(auth).expect(201);

    expect((res.body as RideBody).driver.profile).toBe('4th Year Software Engineering student');
  });

  test('leaves the note empty and the distance at 0 when not given', async () => {
    const { auth } = await createStudent();
    const body = rideBody();
    delete body.dropoffNote;
    delete body.distanceKm;
    delete body.amenities;

    const res = await publish(auth, body).expect(201);
    expect(res.body).toMatchObject({ dropoffNote: '', distanceKm: 0, amenities: [] });

    const nulls = await publish(auth, rideBody({ dropoffNote: null, distanceKm: null })).expect(201);
    expect(nulls.body).toMatchObject({ dropoffNote: '', distanceKm: 0 });

    const blankNote = await publish(auth, rideBody({ dropoffNote: '   ' })).expect(201);
    expect(blankNote.body).toMatchObject({ dropoffNote: '' });
  });

  test('accepts the limits: 1 to 4 seats, free to 50 TND', async () => {
    const { auth } = await createStudent({ displayName: 'Sarra Kefi' });

    const one = await publish(auth, rideBody({ seatCount: 1, pricePerSeat: 0 })).expect(201);
    expect(seatsOf(one.body as RideBody)).toEqual(['s1:driver:Sarra Kefi', 's2:free:Seat #2']);
    expect(one.body).toMatchObject({ pricePerSeat: 0 });

    const four = await publish(auth, rideBody({ seatCount: 4, pricePerSeat: 50 })).expect(201);
    expect(seatsOf(four.body as RideBody)).toEqual([
      's1:driver:Sarra Kefi',
      's2:free:Seat #2',
      's3:free:Seat #3',
      's4:free:Seat #4',
      's5:free:Seat #5',
    ]);
    expect(four.body).toMatchObject({ pricePerSeat: 50 });
  });

  test('numbers the published rides after the demo ones', async () => {
    await seedCarpool(new Types.ObjectId());
    const { auth } = await createStudent();

    const first = await publish(auth).expect(201);
    const second = await publish(auth).expect(201);

    expect([first.body, second.body].map((r) => (r as RideBody).code)).toEqual([
      'ES-4094',
      'ES-4095',
    ]);
    expect(await RideModel.countDocuments()).toBe(5);
  });

  test('gives two rides published at the same time two numbers', async () => {
    const a = await createStudent();
    const b = await createStudent();

    const results = await Promise.all([publish(a.auth), publish(b.auth), publish(a.auth)]);

    expect(results.map((r) => r.status)).toEqual([201, 201, 201]);
    const ids = results.map((r) => (r.body as RideBody).id).sort();
    expect(ids).toEqual(['es-4094', 'es-4095', 'es-4096']);
  });

  test('skips a number that is already taken (e.g. after the counter was reset)', async () => {
    const { auth } = await createStudent();
    await publish(auth).expect(201);
    await RideCounterModel.deleteMany({});

    const res = await publish(auth).expect(201);

    expect((res.body as RideBody).id).toBe('es-4095');
  });

  test('shows the new ride to every student, with the driver seat named', async () => {
    await seedCarpool(new Types.ObjectId());
    const driver = await createStudent({ displayName: 'Dony Mansour' });
    const other = await createStudent({ displayName: 'Omar Ben Salah' });
    await publish(driver.auth).expect(201);

    const seenByOther = await request(app).get('/api/carpool/rides').set(other.auth).expect(200);
    const rides = seenByOther.body as RideBody[];

    // Leaves tomorrow: after the demo rides of today.
    expect(rides.map((r) => r.id)).toContain('es-4094');
    const ride = rides.find((r) => r.id === 'es-4094') as RideBody;
    expect(ride.isMine).toBe(false);
    expect(ride.driver).toMatchObject({ name: 'Dony Mansour', rating: 0, ridesCompleted: 0 });
    expect(seatsOf(ride)).toEqual([
      's1:driver:Dony Mansour',
      's2:free:Seat #2',
      's3:free:Seat #3',
      's4:free:Seat #4',
    ]);
    expect(rides.filter((r) => r.isMine)).toEqual([]);

    const seenByDriver = await request(app).get('/api/carpool/rides').set(driver.auth).expect(200);
    expect((seenByDriver.body as RideBody[]).filter((r) => r.isMine).map((r) => r.id)).toEqual([
      'es-4094',
    ]);
  });

  describe('answers 422 with a readable message', () => {
    const now = () => Date.now();
    const long = (n: number) => 'x'.repeat(n);

    test.each<[string, () => Record<string, unknown>, string]>([
      // Departure and arrival
      ['departure in the past', () => ({ departure: new Date(now() - MINUTE).toISOString() }), 'Le départ doit être dans le futur.'],
      ['departure missing', () => ({ departure: undefined }), "Choisissez l'heure de départ."],
      ['departure not an ISO instant', () => ({ departure: 'tomorrow 8am' }), "Choisissez l'heure de départ."],
      ['departure without a time zone', () => ({ departure: '2030-01-01T08:00:00' }), "Choisissez l'heure de départ."],
      ['arrival missing', () => ({ arrival: undefined }), "Indiquez l'heure d'arrivée."],
      [
        'arrival at the departure time',
        () => {
          const t = new Date(now() + DAY).toISOString();
          return { departure: t, arrival: t };
        },
        "L'arrivée doit être après le départ.",
      ],
      [
        'arrival before departure',
        () => ({
          departure: new Date(now() + DAY).toISOString(),
          arrival: new Date(now() + DAY - 10 * MINUTE).toISOString(),
        }),
        "L'arrivée doit être après le départ.",
      ],
      // Seats and price
      ['0 seats', () => ({ seatCount: 0 }), 'Proposez entre 1 et 4 places.'],
      ['5 seats', () => ({ seatCount: 5 }), 'Proposez entre 1 et 4 places.'],
      ['half a seat', () => ({ seatCount: 2.5 }), 'Proposez entre 1 et 4 places.'],
      ['seats as text', () => ({ seatCount: '3' }), 'Proposez entre 1 et 4 places.'],
      ['seats missing', () => ({ seatCount: undefined }), 'Proposez entre 1 et 4 places.'],
      ['a negative price', () => ({ pricePerSeat: -0.5 }), 'Le prix par place doit être entre 0 et 50 TND.'],
      ['a price above 50 TND', () => ({ pricePerSeat: 50.5 }), 'Le prix par place doit être entre 0 et 50 TND.'],
      ['price missing', () => ({ pricePerSeat: undefined }), 'Le prix par place doit être entre 0 et 50 TND.'],
      // Places and tags
      ['blank pickup', () => ({ pickup: '   ' }), 'Indiquez le point de départ.'],
      ['pickup missing', () => ({ pickup: undefined }), 'Indiquez le point de départ.'],
      ['pickup too long', () => ({ pickup: long(81) }), 'Le point de départ est trop long (80 caractères max).'],
      ['blank pickup tag', () => ({ pickupTag: '' }), 'Ajoutez un repère court pour le départ.'],
      ['pickup tag too long', () => ({ pickupTag: long(25) }), 'Le repère du départ est trop long (24 caractères max).'],
      ['blank dropoff', () => ({ dropoff: ' ' }), 'Indiquez la destination.'],
      ['dropoff too long', () => ({ dropoff: long(81) }), 'La destination est trop longue (80 caractères max).'],
      ['dropoff tag not a string', () => ({ dropoffTag: 42 }), 'Ajoutez un repère court pour la destination.'],
      ['dropoff tag too long', () => ({ dropoffTag: long(25) }), 'Le repère de la destination est trop long (24 caractères max).'],
      // Car
      ['blank car model', () => ({ carModel: '' }), 'Indiquez le modèle de la voiture.'],
      ['car model too long', () => ({ carModel: long(41) }), 'Le modèle est trop long (40 caractères max).'],
      ['blank car color', () => ({ carColor: '  ' }), 'Indiquez la couleur de la voiture.'],
      ['car color too long', () => ({ carColor: long(21) }), 'La couleur est trop longue (20 caractères max).'],
      ['blank plate', () => ({ plate: '' }), "Indiquez la plaque d'immatriculation."],
      ['plate too long', () => ({ plate: long(21) }), 'La plaque est trop longue (20 caractères max).'],
      // Optional fields
      ['note too long', () => ({ dropoffNote: long(141) }), 'La note est trop longue (140 caractères max).'],
      ['distance of 0 km', () => ({ distanceKm: 0 }), 'La distance doit être entre 0,1 et 1000 km.'],
      ['distance above 1000 km', () => ({ distanceKm: 1000.5 }), 'La distance doit être entre 0,1 et 1000 km.'],
      ['unknown amenity', () => ({ amenities: ['petFriendly'] }), 'Choisissez des options valides.'],
      ['amenities not a list', () => ({ amenities: 'musicOk' }), 'Choisissez des options valides.'],
    ])('%s', async (_name, overrides, message) => {
      const { auth } = await createStudent();

      const res = await publish(auth, rideBody(overrides())).expect(422);

      expect(res.body).toEqual({ message });
      expect(await RideModel.countDocuments()).toBe(0);
    });

    test('keeps the limits inclusive (80, 24, 40, 20 and 140 characters, 1000 km)', async () => {
      const { auth } = await createStudent();
      await publish(
        auth,
        rideBody({
          pickup: long(80),
          pickupTag: long(24),
          dropoff: long(80),
          dropoffTag: long(24),
          carModel: long(40),
          carColor: long(20),
          plate: long(20),
          dropoffNote: long(140),
          distanceKm: 1000,
        }),
      ).expect(201);
    });
  });
});

describe('booking a seat in a published ride', () => {
  const reserve = (auth: Auth, seatIds: string[], rideId = 'es-4094') =>
    request(app).post(`/api/carpool/rides/${rideId}/reservations`).set(auth).send({ seatIds });

  test("answers 409 when the driver books a seat in their own ride", async () => {
    const driver = await createStudent({ displayName: 'Dony Mansour' });
    await publish(driver.auth).expect(201);

    const res = await reserve(driver.auth, ['s2']).expect(409);

    expect(res.body).toEqual({ message: "You can't book a seat in your own ride." });
    const ride = await request(app).get('/api/carpool/rides/es-4094').set(driver.auth).expect(200);
    expect(seatsOf(ride.body as RideBody)[1]).toBe('s2:free:Seat #2');
  });

  test('lets another student book it, and the driver sees their name', async () => {
    const driver = await createStudent({ displayName: 'Dony Mansour' });
    const omar = await createStudent({ displayName: 'Omar Ben Salah' });
    await publish(driver.auth).expect(201);

    const booked = await reserve(omar.auth, ['s3']).expect(201);
    expect(seatsOf(booked.body as RideBody)).toEqual([
      's1:driver:Dony Mansour',
      's2:free:Seat #2',
      's3:booked:You',
      's4:free:Seat #4',
    ]);
    expect((booked.body as RideBody).isMine).toBe(false);

    const seenByDriver = await request(app)
      .get('/api/carpool/rides/es-4094')
      .set(driver.auth)
      .expect(200);
    expect(seatsOf(seenByDriver.body as RideBody)[2]).toBe('s3:booked:Omar Ben Salah');
    expect((seenByDriver.body as RideBody).isMine).toBe(true);
  });

  test('still answers "seat taken" for a demo ride, which has no driver account', async () => {
    await seedCarpool(new Types.ObjectId());
    const { auth } = await createStudent();
    const res = await reserve(auth, ['s2'], 'es-4091').expect(409);
    expect(res.body).toEqual({ message: 'This seat is no longer available.' });
  });
});
