import { Router } from 'express';

import { parseQuery } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { requireRole } from '../../middleware/require-role';
import { ROLES_WITH_CLASSES } from '../users/user.model';
import { dateQuerySchema } from './timetable.schemas';
import * as timetable from './timetable.service';

/**
 * Routes under /api/timetable. Every route needs a signed-in student or
 * teacher: admins and alumni have no timetable (403).
 */
export const timetableRouter = Router();
timetableRouter.use(
  requireAuth,
  requireRole(ROLES_WITH_CLASSES, 'Only students and teachers have a timetable.'),
);

/** GET /day?date=YYYY-MM-DD: the student's sessions on that date. */
timetableRouter.get('/day', async (req, res) => {
  const { date } = parseQuery(dateQuerySchema, req.query);
  res.json(await timetable.getDay(currentUserId(res), date));
});

/** GET /week?date=YYYY-MM-DD: the week (Monday to Sunday) containing that date. */
timetableRouter.get('/week', async (req, res) => {
  const { date } = parseQuery(dateQuerySchema, req.query);
  res.json(await timetable.getWeek(currentUserId(res), date));
});
