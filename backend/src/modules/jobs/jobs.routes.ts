import { Router, type Response } from 'express';

import { validateBody } from '../../lib/validate';
import { userLimit } from '../../middleware/rate-limit';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { currentRole, requireRole } from '../../middleware/require-role';
import { jobCreateSchema, jobUpdateSchema } from './jobs.schemas';
import * as jobs from './jobs.service';

/** AI summaries a user may ask for per hour (cached ones included), as in the PWA. */
export const SUMMARY_LIMIT_PER_HOUR = 30;

const ONLY_RECRUITERS = 'Only companies and administrators can post offers.';
const ONLY_STUDENTS = 'Only students can apply to offers.';

/**
 * Routes under /api/jobs. Every route needs a signed-in user. Companies and
 * admins post offers; a company edits and deletes its own, an admin any.
 */
export const jobsRouter = Router();
jobsRouter.use(requireAuth);

const recruitersOnly = requireRole(jobs.RECRUITER_ROLES, ONLY_RECRUITERS);
const viewer = (res: Response) => ({
  id: currentUserId(res),
  role: currentRole(res),
});

jobsRouter.get('/', async (_req, res) => {
  res.json(await jobs.listJobs(currentUserId(res)));
});

jobsRouter.post('/', recruitersOnly, validateBody(jobCreateSchema), async (req, res) => {
  res.status(201).json(await jobs.createJob(currentUserId(res), req.body));
});

jobsRouter.get('/:id', async (req, res) => {
  res.json(await jobs.getJob(req.params.id, currentUserId(res)));
});

/** Partial update: only the fields sent change. */
jobsRouter.patch('/:id', recruitersOnly, validateBody(jobUpdateSchema), async (req, res) => {
  res.json(await jobs.updateJob(req.params.id as string, viewer(res), req.body));
});

jobsRouter.delete('/:id', recruitersOnly, async (req, res) => {
  await jobs.deleteJob(req.params.id as string, viewer(res));
  res.status(204).end();
});

/** No body. `{ summary, keyPoints, skills, idealFor, model, cached }`, in the user's language. */
jobsRouter.post(
  '/:id/summary',
  userLimit({
    name: 'job-summary',
    limit: SUMMARY_LIMIT_PER_HOUR,
    windowMs: 60 * 60 * 1000,
    message: 'Too many summaries. Try again later.',
  }),
  async (req, res) => {
    res.json(await jobs.summarizeJob(req.params.id as string, currentUserId(res)));
  },
);

/** No body needed: answers 201 `{ jobId, appliedAt }`. Only students apply, as in the PWA. */
jobsRouter.post('/:id/applications', requireRole(['student'], ONLY_STUDENTS), async (req, res) => {
  res.status(201).json(await jobs.apply(req.params.id as string, currentUserId(res)));
});
