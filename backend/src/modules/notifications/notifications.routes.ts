import { Router } from 'express';

import { currentUserId, requireAuth } from '../../middleware/require-auth';
import * as notifications from './notifications.service';

/** Routes under /api/notifications. Every route needs a signed-in student. */
export const notificationsRouter = Router();
notificationsRouter.use(requireAuth);

/** The signed-in student's notifications, newest first (a plain array). */
notificationsRouter.get('/', async (_req, res) => {
  res.json(await notifications.listNotifications(currentUserId(res)));
});

notificationsRouter.post('/read-all', async (_req, res) => {
  await notifications.markAllAsRead(currentUserId(res));
  res.status(204).end();
});

notificationsRouter.post('/:id/read', async (req, res) => {
  await notifications.markAsRead(currentUserId(res), req.params.id);
  res.status(204).end();
});
