import { Router, type Request } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  createRideSchema,
  reserveSeatsSchema,
  type CreateRideInput,
  type ReserveSeatsInput,
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

/** Deletes the student's own ride. Answers 204. */
carpoolRouter.delete('/rides/:id', async (req: Request<{ id: string }>, res) => {
  await carpool.deleteRide(currentUserId(res), req.params.id);
  res.sendStatus(204);
});
