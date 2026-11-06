import { Types } from 'mongoose';

import { conflict, notFound, unauthorized } from '../../lib/http-error';
import { UserModel } from '../users/user.model';
import { campusMonth } from './campus-time';
import { CarpoolImpactModel, RideModel, type RideDocument } from './carpool.model';

const RIDE_NOT_FOUND = 'Ride not found.';
const SEAT_TAKEN = 'This seat is no longer available.';

/** Used for a month that has no figures yet. */
export const DEFAULT_MONTHLY_GOAL_KG = 2000;

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
    dropoffNote: ride.dropoffNote,
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

/**
 * Books [seatIds] for the student, all or nothing. The update only matches
 * if every requested seat is still free, and MongoDB applies it atomically,
 * so of two students racing for one seat exactly one gets it.
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
    if (!(await RideModel.exists({ _id: rideId }))) throw notFound(RIDE_NOT_FOUND);
    throw conflict(SEAT_TAKEN);
  }
  return toRideJson(ride, userId);
}

/** CO2 saved by ESPRIT carpoolers this campus month, shared by every student. */
export async function monthlyImpact(now = new Date()): Promise<{ savedKg: number; goalKg: number }> {
  const impact = await CarpoolImpactModel.findById(campusMonth(now));
  return {
    savedKg: impact?.savedKg ?? 0,
    goalKg: impact?.goalKg ?? DEFAULT_MONTHLY_GOAL_KG,
  };
}
