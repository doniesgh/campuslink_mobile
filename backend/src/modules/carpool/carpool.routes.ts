import { Router, type Request } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  createRideSchema,
  reserveSeatsSchema,
  updateRideSchema,
  type CreateRideInput,
  type ReserveSeatsInput,
  type UpdateRideInput,
} from './carpool.schemas';
import * as carpool from './carpool.service';

/** Routes under /api/carpool. Every route needs a signed-in student. */
export const carpoolRouter = Router();
carpoolRouter.use(requireAuth);

carpoolRouter.get('/rides', async (_req, res) => {
  res.json(await carpool.listRides(currentUserId(res)));
});

/** The student publishes a ride as its driver. Answers 201 with the new ride. */
carpoolRouter.post('/rides', validateBody(createRideSchema), async (req, res) => {
  const input = req.body as CreateRideInput;
  res.status(201).json(await carpool.createRide(currentUserId(res), input));
});

carpoolRouter.get('/rides/:id', async (req, res) => {
  res.json(await carpool.getRide(req.params.id, currentUserId(res)));
});

/** Answers 201 with the updated ride, 409 for a taken seat or the driver's own ride. */
carpoolRouter.post(
  '/rides/:id/reservations',
  validateBody(reserveSeatsSchema),
  // Typed by hand: after a middleware, Express no longer infers `:id` from the path.
  async (req: Request<{ id: string }>, res) => {
    const { seatIds } = req.body as ReserveSeatsInput;
    res.status(201).json(await carpool.reserveSeats(req.params.id, currentUserId(res), seatIds));
  },
);

/** The driver edits their ride. 403 if it isn't theirs, 409 if too many seats are booked. */
carpoolRouter.put(
  '/rides/:id',
  validateBody(updateRideSchema),
  async (req: Request<{ id: string }>, res) => {
    const input = req.body as UpdateRideInput;
    res.json(await carpool.updateRide(req.params.id, currentUserId(res), input));
  },
);

/** The driver deletes their ride. Answers 204. */
carpoolRouter.delete('/rides/:id', async (req, res) => {
  await carpool.deleteRide(req.params.id, currentUserId(res));
  res.status(204).end();
});

/** The driver cancels the booking of one seat. Answers 200 with the updated ride. */
carpoolRouter.delete('/rides/:id/reservations/:seatId', async (req, res) => {
  res.json(await carpool.cancelReservation(req.params.id, currentUserId(res), req.params.seatId));
});


