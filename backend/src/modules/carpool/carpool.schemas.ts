import { z } from 'zod';

import { AMENITIES } from './carpool.model';

// Messages are shown as-is in the app, so they are written for students.

export const reserveSeatsSchema = z.object({
  seatIds: z
    .array(z.string({ error: 'Choose a valid seat' }).trim().min(1, 'Choose a valid seat'), {
      error: 'Choose at least one seat',
    })
    .min(1, 'Choose at least one seat')
    .max(10, 'You can book at most 10 seats at once')
    // The same seat twice is the same reservation.
    .transform((ids) => [...new Set(ids)]),
});

export type ReserveSeatsInput = z.infer<typeof reserveSeatsSchema>;

/**
 * Limits of a published ride. The app checks the same rules, with the same
 * (French) messages, before sending: lib/features/carpooling/domain/new_ride_rules.dart.
 * Change both together.
 */
export const RIDE_LIMITS = {
  placeMaxLength: 80,
  tagMaxLength: 24,
  carModelMaxLength: 40,
  carColorMaxLength: 20,
  plateMaxLength: 20,
  noteMaxLength: 140,
  minSeats: 1,
  maxSeats: 4,
  maxPricePerSeat: 50,
  minDistanceKm: 0.1,
  maxDistanceKm: 1000,
} as const;

const L = RIDE_LIMITS;

// The "Proposer un trajet" form is in French, so these messages are too.
export const RIDE_MESSAGES = {
  pickupMissing: 'Indiquez le point de départ.',
  pickupTooLong: `Le point de départ est trop long (${L.placeMaxLength} caractères max).`,
  pickupTagMissing: 'Ajoutez un repère court pour le départ.',
  pickupTagTooLong: `Le repère du départ est trop long (${L.tagMaxLength} caractères max).`,
  dropoffMissing: 'Indiquez la destination.',
  dropoffTooLong: `La destination est trop longue (${L.placeMaxLength} caractères max).`,
  dropoffTagMissing: 'Ajoutez un repère court pour la destination.',
  dropoffTagTooLong: `Le repère de la destination est trop long (${L.tagMaxLength} caractères max).`,
  departureMissing: "Choisissez l'heure de départ.",
  departurePast: 'Le départ doit être dans le futur.',
  arrivalMissing: "Indiquez l'heure d'arrivée.",
  arrivalBeforeDeparture: "L'arrivée doit être après le départ.",
  seats: `Proposez entre ${L.minSeats} et ${L.maxSeats} places.`,
  price: `Le prix par place doit être entre 0 et ${L.maxPricePerSeat} TND.`,
  carModelMissing: 'Indiquez le modèle de la voiture.',
  carModelTooLong: `Le modèle est trop long (${L.carModelMaxLength} caractères max).`,
  carColorMissing: 'Indiquez la couleur de la voiture.',
  carColorTooLong: `La couleur est trop longue (${L.carColorMaxLength} caractères max).`,
  plateMissing: "Indiquez la plaque d'immatriculation.",
  plateTooLong: `La plaque est trop longue (${L.plateMaxLength} caractères max).`,
  noteTooLong: `La note est trop longue (${L.noteMaxLength} caractères max).`,
  distance: `La distance doit être entre 0,1 et ${L.maxDistanceKm} km.`,
  amenities: 'Choisissez des options valides.',
} as const;

const M = RIDE_MESSAGES;

/** A trimmed, non-blank string of at most [max] characters. */
const text = (missing: string, max: number, tooLong: string) =>
  z.string({ error: missing }).trim().min(1, missing).max(max, tooLong);

/** An ISO-8601 instant with "Z" or an offset (a bare local time is ambiguous). */
const instant = (message: string) =>
  z.iso.datetime({ offset: true, error: message }).transform((s) => new Date(s));

/**
 * POST /carpool/rides: the ride the signed-in student offers as the driver.
 * `seatCount` is the number of passenger seats (the driver's is added).
 */
export const createRideSchema = z
  .object({
    pickup: text(M.pickupMissing, L.placeMaxLength, M.pickupTooLong),
    pickupTag: text(M.pickupTagMissing, L.tagMaxLength, M.pickupTagTooLong),
    dropoff: text(M.dropoffMissing, L.placeMaxLength, M.dropoffTooLong),
    dropoffTag: text(M.dropoffTagMissing, L.tagMaxLength, M.dropoffTagTooLong),
    // Checked against the clock when the request arrives.
    departure: instant(M.departureMissing).refine((d) => d.getTime() > Date.now(), M.departurePast),
    arrival: instant(M.arrivalMissing),
    seatCount: z
      .number({ error: M.seats })
      .int(M.seats)
      .min(L.minSeats, M.seats)
      .max(L.maxSeats, M.seats),
    // 0 means free.
    pricePerSeat: z.number({ error: M.price }).min(0, M.price).max(L.maxPricePerSeat, M.price),
    carModel: text(M.carModelMissing, L.carModelMaxLength, M.carModelTooLong),
    carColor: text(M.carColorMissing, L.carColorMaxLength, M.carColorTooLong),
    plate: text(M.plateMissing, L.plateMaxLength, M.plateTooLong),
    amenities: z
      .array(z.enum(AMENITIES, { error: M.amenities }), { error: M.amenities })
      .default([])
      .transform((list) => [...new Set(list)]),
    dropoffNote: z.string({ error: M.noteTooLong }).trim().max(L.noteMaxLength, M.noteTooLong).nullish(),
    distanceKm: z
      .number({ error: M.distance })
      .min(L.minDistanceKm, M.distance)
      .max(L.maxDistanceKm, M.distance)
      .nullish(),
  })
  // Zod also runs this when a field above failed: only compare two real dates.
  .refine(
    ({ departure, arrival }) =>
      !(departure instanceof Date && arrival instanceof Date) || arrival > departure,
    { message: M.arrivalBeforeDeparture, path: ['arrival'] },
  );

export type CreateRideInput = z.infer<typeof createRideSchema>;
