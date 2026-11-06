import { Router } from 'express';

import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { dateQuerySchema, parseQuery } from './timetable.schemas';
import * as timetable from './timetable.service';

/** Routes under /api/timetable. Every route needs a signed-in student. */
export const timetableRouter = Router();
timetableRouter.use(requireAuth);

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
