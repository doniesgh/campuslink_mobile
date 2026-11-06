import { Router } from 'express';

import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { clock } from './academic-calendar';
import { getProfile } from './profile.service';

/** Routes under /api/profile. Every route needs a signed-in student. */
export const profileRouter = Router();
profileRouter.use(requireAuth);

/** The signed-in student's academic profile and digital ID. */
profileRouter.get('/', async (_req, res) => {
  res.json(await getProfile(currentUserId(res), clock.now()));
});
