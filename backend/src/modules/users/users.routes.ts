import { Router } from 'express';

import { unauthorized } from '../../lib/http-error';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { toPublicUser, UserModel } from './user.model';

export const usersRouter = Router();

/** The signed-in user (sent as-is, not wrapped: the app reads it directly). */
usersRouter.get('/me', requireAuth, async (_req, res) => {
  const user = await UserModel.findById(currentUserId(res));
  // A valid token for a deleted account: treat it as an expired session.
  if (!user) throw unauthorized();
  res.json(toPublicUser(user));
});
