import { Router } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { updateMeSchema, type UpdateMeInput } from './users.schemas';
import * as users from './users.service';

/** Routes under /api/users: the signed-in user's own account. */
export const usersRouter = Router();

/** The signed-in user (sent as-is, not wrapped: the app reads it directly). */
usersRouter.get('/me', requireAuth, async (_req, res) => {
  res.json(await users.getMe(currentUserId(res)));
});

/** Changes the signed-in user's own settings (`{ locale }`), and sends the account back. */
usersRouter.patch('/me', requireAuth, validateBody(updateMeSchema), async (req, res) => {
  res.json(await users.updateMe(currentUserId(res), req.body as UpdateMeInput));
});
