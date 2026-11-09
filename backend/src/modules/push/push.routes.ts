import { Router } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  registerDeviceSchema,
  unregisterDeviceSchema,
  type RegisterDeviceInput,
  type UnregisterDeviceInput,
} from './push.schemas';
import * as devices from './push-devices.service';

/**
 * Routes under /api/push: the phones that receive the signed-in user's push
 * notifications. Every route needs a signed-in user.
 */
export const pushRouter = Router();
pushRouter.use(requireAuth);

/** Registers this phone's FCM token (again after each sign-in, or when FCM changes it). */
pushRouter.put('/devices', validateBody(registerDeviceSchema), async (req, res) => {
  await devices.registerDevice(currentUserId(res), req.body as RegisterDeviceInput);
  res.status(204).end();
});

/** Stops the pushes to this phone (the user turned them off). Unknown tokens are fine. */
pushRouter.delete('/devices', validateBody(unregisterDeviceSchema), async (req, res) => {
  await devices.unregisterDevice(currentUserId(res), (req.body as UnregisterDeviceInput).token);
  res.status(204).end();
});
