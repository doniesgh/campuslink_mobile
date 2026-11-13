import { Types } from 'mongoose';

import { conflict, notFound, unauthorized } from '../../lib/http-error';
import { StudentProfileModel } from '../profile/profile.model';
import { UserModel } from '../users/user.model';
import {
  RideCounterModel,
  RideModel,
  type RideDocument,
} from './carpool.model';
import type { CreateRideInput } from './carpool.schemas';

const RIDE_NOT_FOUND = 'Ride not found.';
const SEAT_TAKEN = 'This seat is no longer available.';
const OWN_RIDE = "You can't book a seat in your own ride.";

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
  seats: { id: string; label: string; status: string }[];
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
      return { id: seat.seatId, label, status: seat.status };
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
 */
export async function reserveSeats(
  rideId: string,
  userId: string,
  seatIds: string[],
): Promise<RideJson> {
  const student = await UserModel.findById(userId).select('displayName');
  // A valid token for a deleted account: treat it as an expired session.
  if (!student) throw unauthorized();

  const ride = await RideModel.findOneAndUpdate(
    {
      _id: rideId,
      driverId: { $ne: student._id },
      seats: { $all: seatIds.map((seatId) => ({ $elemMatch: { seatId, status: 'free' } })) },
    },
    {
      $set: {
        'seats.$[seat].status': 'booked',
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

/** Deletes ride [rideId] if [userId] is its driver. Throws 403 otherwise, 404 if gone. */
export async function deleteRide(userId: string, rideId: string): Promise<void> {
  const ride = await RideModel.findById(rideId).select('driverId').lean();
  if (!ride) throw notFound(RIDE_NOT_FOUND);
  if (!ride.driverId || !ride.driverId.equals(userId)) throw unauthorized();
  await RideModel.deleteOne({ _id: rideId });
}
