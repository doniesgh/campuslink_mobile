import { model, Schema, type HydratedDocument, type InferSchemaType } from 'mongoose';

// Sent as-is to the app, which reads them as its SeatStatus / RideAmenity enum names.
export const SEAT_STATUSES = ['driver', 'booked', 'free'] as const;
export const AMENITIES = ['nonSmoking', 'airConditioned', 'musicOk'] as const;

const seatSchema = new Schema(
  {
    /** Stable within the ride ("s1" is the driver's seat). */
    seatId: { type: String, required: true },
    status: { type: String, enum: SEAT_STATUSES, required: true },

    /** The student who booked it. Null for the driver, free seats and demo passengers. */
    passengerId: { type: Schema.Types.ObjectId, ref: 'User', default: null },

    /** Name shown to the other students (demo passengers have no account). */
    passengerName: { type: String, default: null },
  },
  { _id: false },
);

const driverSchema = new Schema(
  {
    name: { type: String, required: true },
    rating: { type: Number, required: true },
    profile: { type: String, required: true },
    ridesCompleted: { type: Number, required: true },
    carModel: { type: String, required: true },
    carColor: { type: String, required: true },
    plate: { type: String, required: true },
    isCarVerified: { type: Boolean, default: false },
  },
  { _id: false },
);

/**
 * A ride offered by a student driver. Booked seats live inside the ride, so
 * a reservation is a single atomic update (two students can't get one seat).
 */
const rideSchema = new Schema(
  {
    /** Readable id used in the app's URLs and notifications, e.g. "es-4091". */
    _id: { type: String, required: true },
    code: { type: String, required: true },

    /**
     * The student who published the ride. Null for the demo rides, whose
     * drivers have no account. Indexed to find a student's own rides.
     */
    driverId: { type: Schema.Types.ObjectId, ref: 'User', default: null, index: true },

    pickup: { type: String, required: true },
    dropoff: { type: String, required: true },
    pickupTag: { type: String, required: true },
    dropoffTag: { type: String, required: true },
    /** Empty when the driver added no note. */
    dropoffNote: { type: String, default: '' },
    departure: { type: Date, required: true, index: true },
    arrival: { type: Date, required: true },
    /** 0 when the driver didn't give it. */
    distanceKm: { type: Number, required: true },
    pricePerSeat: { type: Number, required: true },
    driver: { type: driverSchema, required: true },
    seats: { type: [seatSchema], required: true },
    amenities: { type: [{ type: String, enum: AMENITIES }], default: [] },
  },
  { timestamps: true },
);

export type Ride = InferSchemaType<typeof rideSchema>;
export type RideDocument = HydratedDocument<Ride>;

export const RideModel = model('Ride', rideSchema);

/**
 * Hands out the numbers of published rides ("ES-4094", "ES-4095"...), one
 * atomic increment per ride. A single document: { _id: "rides", seq }.
 */
const rideCounterSchema = new Schema({
  _id: { type: String, required: true },
  seq: { type: Number, required: true },
});

export const RideCounterModel = model('RideCounter', rideCounterSchema);
