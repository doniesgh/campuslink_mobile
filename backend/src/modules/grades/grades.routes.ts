import { Router } from 'express';

import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { clock } from '../profile/academic-calendar';
import { getTranscript } from './grades.service';

/** Routes under /api/grades. Every route needs a signed-in student. */
export const gradesRouter = Router();
gradesRouter.use(requireAuth);

/** The signed-in student's transcript: raw marks of the published semesters, latest first. */
gradesRouter.get('/transcript', async (_req, res) => {
  res.json(await getTranscript(currentUserId(res), clock.now()));
});
