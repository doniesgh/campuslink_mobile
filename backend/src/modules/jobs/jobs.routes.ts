import { Router } from 'express';

import { currentUserId, requireAuth } from '../../middleware/require-auth';
import * as jobs from './jobs.service';

/** Routes under /api/jobs. Every route needs a signed-in student. */
export const jobsRouter = Router();
jobsRouter.use(requireAuth);

jobsRouter.get('/', async (_req, res) => {
  res.json(await jobs.listJobs(currentUserId(res)));
});

jobsRouter.get('/:id', async (req, res) => {
  res.json(await jobs.getJob(req.params.id, currentUserId(res)));
});

/** No body needed: answers 201 `{ jobId, appliedAt }`. */
jobsRouter.post('/:id/applications', async (req, res) => {
  res.status(201).json(await jobs.apply(req.params.id, currentUserId(res)));
});
