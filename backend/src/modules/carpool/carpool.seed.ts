import type { Types } from 'mongoose';

import { atCampusTime, campusMonth } from './campus-time';
import {  RideModel } from './carpool.model';

// The rides of the app's MockCarpoolRepository. Times are campus wall-clock
// times "today" (day 0) or "tomorrow" (day 1), resolved when the seed runs.
const DEMO_RIDES = [
  {
    _id: 'es-4091',
    code: 'ES-4091',
    pickup: 'Tunis Centre (Passage)',
    dropoff: 'ESPRIT Ghazela (Bloc H)',
    pickupTag: 'Passage',
    dropoffTag: 'ESPRIT Bloc H',
    dropoffNote: 'Drop-off direct at Bloc H (Ghazela Technopark)',
    departure: { day: 0, hour: 13, minute: 15 },
    arrival: { day: 0, hour: 13, minute: 45 },
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
    // A name means a seat booked by a demo passenger (no account).
    seats: ['driver', 'Ahmed D.', null, null],
    amenities: ['nonSmoking', 'airConditioned', 'musicOk'],
  },
  {
    _id: 'es-4092',
    code: 'ES-4092',
    pickup: 'Ariana Ville (Station Métro 2)',
    dropoff: 'ESPRIT Charguia 2',
    pickupTag: 'Métro 2',
    dropoffTag: 'ESPRIT Charguia',
    dropoffNote: 'Drop-off at the main entrance',
    departure: { day: 1, hour: 8, minute: 0 },
    arrival: { day: 1, hour: 8, minute: 25 },
    distanceKm: 9.6,
    pricePerSeat: 2.0,
    driver: {
      name: 'Youssef M.',
      rating: 4.8,
      profile: '3rd Year Computer Science student',
      ridesCompleted: 21,
      carModel: 'Peugeot 208',
      carColor: 'Grey',
      plate: '195 · TN · 4410',
      isCarVerified: true,
    },
    seats: ['driver', null, null, null],
    amenities: ['nonSmoking', 'airConditioned'],
  },
  {
    _id: 'es-4093',
    code: 'ES-4093',
    pickup: 'ESPRIT Ghazela',
    dropoff: 'La Marsa / Gammarth',
    pickupTag: 'ESPRIT Ghazela',
    dropoffTag: 'La Marsa',
    dropoffNote: 'Drop-off at La Marsa Corniche',
    departure: { day: 0, hour: 17, minute: 30 },
    arrival: { day: 0, hour: 18, minute: 5 },
    distanceKm: 18.4,
    pricePerSeat: 3.0,
    driver: {
      name: 'Kenza B.',
      rating: 5.0,
      profile: '5th Year Software Engineering student',
      ridesCompleted: 54,
      carModel: 'Kia Picanto',
      carColor: 'Red',
      plate: '207 · TN · 7731',
      isCarVerified: true,
    },
    seats: ['driver', 'Rami T.', 'Lina S.', null],
    amenities: ['airConditioned', 'musicOk'],
  },
];

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Must be idempotent (safe to run again).
 *
 * Each run puts the demo rides back on "today" / "tomorrow" relative to
 * [now], with the mock's seats: a refreshed ride is a new trip, so earlier
 * bookings on it are dropped. The impact figures go on the current month.
 */
export async function seedCarpool(_demoUserId: Types.ObjectId, now = new Date()): Promise<void> {
  for (const { departure, arrival, seats, ...ride } of DEMO_RIDES) {
    await RideModel.replaceOne(
      { _id: ride._id },
      {
        ...ride,
        departure: atCampusTime(now, departure.day, departure.hour, departure.minute),
        arrival: atCampusTime(now, arrival.day, arrival.hour, arrival.minute),
        seats: seats.map((passenger, index) => ({
          seatId: `s${index + 1}`,
          status: passenger === 'driver' ? 'driver' : passenger ? 'booked' : 'free',
          passengerId: null,
          passengerName: passenger === 'driver' ? null : passenger,
        })),
      },
      { upsert: true, runValidators: true },
    );
  }

 
}
