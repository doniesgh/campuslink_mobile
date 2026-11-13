import { Types } from 'mongoose';

import { conflict, forbidden, notFound, unauthorized } from '../../lib/http-error';
import { StudentProfileModel } from '../profile/profile.model';
import { UserModel } from '../users/user.model';
import {
  RideCounterModel,
  RideModel,
  type RideDocument,
} from './carpool.model';
import type { CreateRideInput, UpdateRideInput } from './carpool.schemas';

const RIDE_NOT_FOUND = 'Ride not found.';
const SEAT_TAKEN = 'This seat is no longer available.';
const OWN_RIDE = "You can't book a seat in your own ride.";
const NOT_YOUR_RIDE = 'Only the driver can change this ride.';
const SEAT_NOT_BOOKED = 'This seat is not booked.';
const NO_PENDING_REQUEST = 'There is no pending request for this seat.';
const NOT_YOUR_BOOKING = 'Only the driver or the student who booked can cancel this seat.';
const RIDE_CHANGED = 'The ride was just updated. Please try again.';

/** What the API sends for a ride (the shape the app's RideModel.fromJson reads). */
export interface RideJson {
  id: string;
  code: string;
  pickup: string;
  dropoff: string;
  pickupTag: string;
  dropoffTag: string;
  dropoffNote: string;
  departure: string;
  arrival: string;
  distanceKm: number;
  pricePerSeat: number;
  driver: {
    name: string;
    rating: number;
    profile: string;
    ridesCompleted: number;
    carModel: string;
    carColor: string;
    plate: string;
    isCarVerified: boolean;
  };
  /** `isMine`: the signed-in student booked (or asked for) this seat. */
  seats: { id: string; label: string; status: string; isMine: boolean }[];
  amenities: string[];
  /** True for the student who published the ride (they can't book in it). */
  isMine: boolean;
}

/**
 * Seats as the app shows them: the driver's name, "You" for the student
 * asking, the passenger's name for other bookings, "Seat #3" when free.
 */
export function toRideJson(ride: RideDocument, userId: string): RideJson {
  const { driver } = ride;
  return {
    id: ride.id as string,
    code: ride.code,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    pickupTag: ride.pickupTag,
    dropoffTag: ride.dropoffTag,
    dropoffNote: ride.dropoffNote ?? '',
    departure: ride.departure.toISOString(),
    arrival: ride.arrival.toISOString(),
    distanceKm: ride.distanceKm,
    pricePerSeat: ride.pricePerSeat,
    driver: {
      name: driver.name,
      rating: driver.rating,
      profile: driver.profile,
      ridesCompleted: driver.ridesCompleted,
      carModel: driver.carModel,
      carColor: driver.carColor,
      plate: driver.plate,
      isCarVerified: driver.isCarVerified,
    },
    seats: ride.seats.map((seat, index) => {
      let label: string;
      if (seat.status === 'driver') label = driver.name;
      else if (seat.status === 'free') label = `Seat #${index + 1}`;
      else if (seat.passengerId?.equals(userId)) label = 'You';
      else label = seat.passengerName ?? 'Student';
      return {
        id: seat.seatId,
        label,
        status: seat.status,
        isMine: seat.passengerId?.equals(userId) ?? false,
      };
    }),
    amenities: [...ride.amenities],
    isMine: ride.driverId?.equals(userId) ?? false,
  };
}

/** Every ride, soonest departure first. */
export async function listRides(userId: string): Promise<RideJson[]> {
  const rides = await RideModel.find().sort({ departure: 1, _id: 1 });
  return rides.map((ride) => toRideJson(ride, userId));
}

export async function getRide(rideId: string, userId: string): Promise<RideJson> {
  const ride = await RideModel.findById(rideId);
  if (!ride) throw notFound(RIDE_NOT_FOUND);
  return toRideJson(ride, userId);
}

/** The rides where the student has a seat (asked for or confirmed), soonest first. */
export async function listMyBookings(userId: string): Promise<RideJson[]> {
  const rides = await RideModel.find({ 'seats.passengerId': new Types.ObjectId(userId) }).sort({
    departure: 1,
    _id: 1,
  });
  return rides.map((ride) => toRideJson(ride, userId));
}

/**
 * The rides the student drives that have passengers: students who
 * asked for a seat (pending, waiting for the answer) or who are confirmed
 * (booked). Soonest first.
 */
export async function listMyRideRequests(userId: string): Promise<RideJson[]> {
  const rides = await RideModel.find({
    driverId: new Types.ObjectId(userId),
    seats: { $elemMatch: { status: { $in: ['pending', 'booked'] } } },
  }).sort({ departure: 1, _id: 1 });
  return rides.map((ride) => toRideJson(ride, userId));
}

/** Published rides are numbered after the demo ones (ES-4091 to ES-4093). */
const LAST_DEMO_RIDE_NUMBER = 4093;

/** Attempts at a free ride number before giving up (see [createRide]). */
const MAX_NUMBER_ATTEMPTS = 5;

/** The next ride number: atomic, so two rides published at once get two numbers. */
async function nextRideNumber(): Promise<number> {
  const counter = await RideCounterModel.findOneAndUpdate(
    { _id: 'rides' },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' },
  );
  return LAST_DEMO_RIDE_NUMBER + (counter?.seq ?? 1);
}

const isDuplicateKey = (err: unknown) =>
  typeof err === 'object' && err !== null && (err as { code?: unknown }).code === 11000;

const ORDINALS = ['1st', '2nd', '3rd', '4th', '5th'];

/**
 * "4th Year Software Engineering student" from the student's profile, or a
 * neutral "ESPRIT student" when the school hasn't set one (the profile
 * module's default would be a guess).
 */
async function driverProfileLine(userId: string): Promise<string> {
  const profile = await StudentProfileModel.findOne({ userId }).select('yearOfStudy program');
  const year = profile ? ORDINALS[profile.yearOfStudy - 1] : undefined;
  if (!profile || !year || !profile.program) return 'ESPRIT student';
  return `${year} Year ${profile.program} student`;
}

/**
 * Publishes the ride the student offers as its driver: the driver's seat
 * ("s1", labelled with their name) and [input.seatCount] free seats.
 * There is no rating system yet, so the driver has a rating of 0 and 0
 * rides, which the app shows as "New driver". A student's car isn't
 * inspected, so it isn't verified.
 */
export async function createRide(userId: string, input: CreateRideInput): Promise<RideJson> {
  const [student, profile] = await Promise.all([
    UserModel.findById(userId).select('displayName'),
    driverProfileLine(userId),
  ]);
  // A valid token for a deleted account: treat it as an expired session.
  if (!student) throw unauthorized();

  const ride = {
    driverId: new Types.ObjectId(userId),
    pickup: input.pickup,
    pickupTag: input.pickupTag,
    dropoff: input.dropoff,
    dropoffTag: input.dropoffTag,
    dropoffNote: input.dropoffNote ?? '',
    departure: input.departure,
    arrival: input.arrival,
    distanceKm: input.distanceKm ?? 0,
    pricePerSeat: input.pricePerSeat,
    driver: {
      name: student.displayName,
      rating: 0,
      profile,
      ridesCompleted: 0,
      carModel: input.carModel,
      carColor: input.carColor,
      plate: input.plate,
      isCarVerified: false,
    },
    seats: Array.from({ length: input.seatCount + 1 }, (_, index) => ({
      seatId: `s${index + 1}`,
      status: index === 0 ? 'driver' : 'free',
      passengerId: null,
      passengerName: null,
    })),
    amenities: input.amenities,
  };

  // The counter normally gives a free number. If it was reset while rides
  // remain, the insert hits a taken id: skip to the next number.
  for (let attempt = 1; ; attempt += 1) {
    const number = await nextRideNumber();
    try {
      const created = await RideModel.create({ _id: `es-${number}`, code: `ES-${number}`, ...ride });
      return toRideJson(created, userId);
    } catch (err) {
      if (!isDuplicateKey(err) || attempt >= MAX_NUMBER_ATTEMPTS) throw err;
    }
  }
}

/**
 * Books [seatIds] for the student, all or nothing. The update only matches
 * if every requested seat is still free, and MongoDB applies it atomically,
 * so of two students racing for one seat exactly one gets it. The driver
 * can't book a seat in their own ride.
 *
 * On a ride published by a student the seats become "pending": the driver
 * accepts or refuses them. Demo rides have no driver account, so their
 * seats are booked right away.
 */
export async function reserveSeats(
  rideId: string,
  userId: string,
  seatIds: string[],
): Promise<RideJson> {
  const student = await UserModel.findById(userId).select('displayName');
  // A valid token for a deleted account: treat it as an expired session.
  if (!student) throw unauthorized();

  const target = await RideModel.findById(rideId).select('driverId');
  if (!target) throw notFound(RIDE_NOT_FOUND);
  if (target.driverId?.equals(student._id)) throw conflict(OWN_RIDE);
  const status = target.driverId ? 'pending' : 'booked';

  const ride = await RideModel.findOneAndUpdate(
    {
      _id: rideId,
      driverId: { $ne: student._id },
      seats: { $all: seatIds.map((seatId) => ({ $elemMatch: { seatId, status: 'free' } })) },
    },
    {
      $set: {
        'seats.$[seat].status': status,
        'seats.$[seat].passengerId': new Types.ObjectId(userId),
        'seats.$[seat].passengerName': student.displayName,
      },
    },
    { arrayFilters: [{ 'seat.seatId': { $in: seatIds } }], returnDocument: 'after' },
  );
  if (!ride) {
    const existing = await RideModel.findById(rideId).select('driverId');
    if (!existing) throw notFound(RIDE_NOT_FOUND);
    if (existing.driverId?.equals(student._id)) throw conflict(OWN_RIDE);
    throw conflict(SEAT_TAKEN);
  }
  return toRideJson(ride, userId);
}

/**
 * Loads a ride and makes sure [userId] is its driver: 404 for an unknown
 * ride, 403 for a ride that belongs to someone else (or to a demo driver).
 */
async function findOwnRide(rideId: string, userId: string): Promise<RideDocument> {
  const ride = await RideModel.findById(rideId);
  if (!ride) throw notFound(RIDE_NOT_FOUND);
  if (!ride.driverId?.equals(userId)) throw forbidden(NOT_YOUR_RIDE);
  return ride;
}

/** "s4" -> 4 (0 for an id that doesn't follow the "s<number>" pattern). */
const seatNumber = (seatId: string) => Number(/^s(\d+)$/.exec(seatId)?.[1] ?? 0);

/**
 * The driver edits their ride. Booked seats are kept as they are: only the
 * number of free seats follows [input.seatCount] (free seats are added at
 * the end, or removed from the end). It can't go below the number of seats
 * already booked.
 */
export async function updateRide(
  rideId: string,
  userId: string,
  input: UpdateRideInput,
): Promise<RideJson> {
  const ride = await findOwnRide(rideId, userId);

  // Seats asked for count too: a student is waiting on them.
  const booked = ride.seats.filter(
    (seat) => seat.status === 'booked' || seat.status === 'pending',
  ).length;
  if (input.seatCount < booked) {
    throw conflict(
      `${booked} ${booked === 1 ? 'place est déjà réservée' : 'places sont déjà réservées'} : ` +
        'annulez des réservations avant de réduire le nombre de places.',
    );
  }

  const seats = ride.seats.map((seat) => ({
    seatId: seat.seatId,
    status: seat.status,
    passengerId: seat.passengerId ?? null,
    passengerName: seat.passengerName ?? null,
  }));
  const wanted = input.seatCount + 1; // + the driver's seat
  while (seats.length > wanted) {
    const lastFree = seats.map((s) => s.status).lastIndexOf('free');
    seats.splice(lastFree, 1);
  }
  let next = Math.max(0, ...seats.map((seat) => seatNumber(seat.seatId))) + 1;
  while (seats.length < wanted) {
    seats.push({ seatId: `s${next}`, status: 'free', passengerId: null, passengerName: null });
    next += 1;
  }

  ride.pickup = input.pickup;
  ride.pickupTag = input.pickupTag;
  ride.dropoff = input.dropoff;
  ride.dropoffTag = input.dropoffTag;
  ride.dropoffNote = input.dropoffNote ?? '';
  ride.departure = input.departure;
  ride.arrival = input.arrival;
  ride.distanceKm = input.distanceKm ?? 0;
  ride.pricePerSeat = input.pricePerSeat;
  ride.driver.carModel = input.carModel;
  ride.driver.carColor = input.carColor;
  ride.driver.plate = input.plate;
  ride.amenities = input.amenities;
  ride.seats = seats as typeof ride.seats;

  try {
    // Replacing the seats is versioned: a seat booked in the meantime makes
    // this save fail instead of being overwritten.
    await ride.save();
  } catch (err) {
    if ((err as { name?: string }).name === 'VersionError') throw conflict(RIDE_CHANGED);
    throw err;
  }
  return toRideJson(ride, userId);
}

/** The driver deletes their ride, with the bookings in it. */
export async function deleteRide(rideId: string, userId: string): Promise<void> {
  const deleted = await RideModel.findOneAndDelete({ _id: rideId, driverId: new Types.ObjectId(userId) });
  if (deleted) return;
  // Nothing deleted: say why.
  await findOwnRide(rideId, userId);
  throw notFound(RIDE_NOT_FOUND);
}

/**
 * Cancels the booking (or the pending request) of [seatId]: the seat is free
 * again. Allowed to the ride's driver and to the student who booked it.
 * Atomic like [reserveSeats]: it only matches a seat that is still taken.
 */
export async function cancelReservation(
  rideId: string,
  userId: string,
  seatId: string,
): Promise<RideJson> {
  const me = new Types.ObjectId(userId);
  const taken = { $in: ['pending', 'booked'] };
  const ride = await RideModel.findOneAndUpdate(
    {
      _id: rideId,
      $or: [
        { driverId: me, seats: { $elemMatch: { seatId, status: taken } } },
        { seats: { $elemMatch: { seatId, status: taken, passengerId: me } } },
      ],
    },
    {
      $set: {
        'seats.$[seat].status': 'free',
        'seats.$[seat].passengerId': null,
        'seats.$[seat].passengerName': null,
      },
    },
    { arrayFilters: [{ 'seat.seatId': seatId }], returnDocument: 'after' },
  );
  if (!ride) {
    const existing = await RideModel.findById(rideId);
    if (!existing) throw notFound(RIDE_NOT_FOUND);
    const seat = existing.seats.find((s) => s.seatId === seatId);
    if (!seat || seat.status === 'free' || seat.status === 'driver') throw conflict(SEAT_NOT_BOOKED);
    throw forbidden(NOT_YOUR_BOOKING);
  }
  return toRideJson(ride, userId);
}

/**
 * The driver answers a pending request: accepted (the seat is booked) or
 * refused (the seat is free again). Only matches a seat still pending.
 */
async function answerRequest(
  rideId: string,
  userId: string,
  seatId: string,
  accept: boolean,
): Promise<RideJson> {
  const ride = await RideModel.findOneAndUpdate(
    {
      _id: rideId,
      driverId: new Types.ObjectId(userId),
      seats: { $elemMatch: { seatId, status: 'pending' } },
    },
    {
      $set: accept
        ? { 'seats.$[seat].status': 'booked' }
        : {
            'seats.$[seat].status': 'free',
            'seats.$[seat].passengerId': null,
            'seats.$[seat].passengerName': null,
          },
    },
    { arrayFilters: [{ 'seat.seatId': seatId }], returnDocument: 'after' },
  );
  if (!ride) {
    await findOwnRide(rideId, userId); // 404 / 403
    throw conflict(NO_PENDING_REQUEST);
  }
  return toRideJson(ride, userId);
}

export const acceptReservation = (rideId: string, userId: string, seatId: string) =>
  answerRequest(rideId, userId, seatId, true);

export const refuseReservation = (rideId: string, userId: string, seatId: string) =>
  answerRequest(rideId, userId, seatId, false);
