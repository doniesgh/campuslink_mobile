import { Router, type Request } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { lostItemRequestSchema, type LostItemRequestInput } from './forum.schemas';
import * as forum from './forum.service';

/** Routes under /api/forum. Every route needs a signed-in student. */
export const forumRouter = Router();
forumRouter.use(requireAuth);

forumRouter.get('/highlights', async (_req, res) => {
  res.json(await forum.listHighlights());
});

forumRouter.get('/lost-items', async (_req, res) => {
  res.json(await forum.listLostItems());
});

forumRouter.post(
  '/lost-items/:id/requests',
  validateBody(lostItemRequestSchema),
  async (req: Request<{ id: string }>, res) => {
    const { proof } = req.body as LostItemRequestInput;
    const request = await forum.sendLostItemRequest(currentUserId(res), req.params.id, proof);
    res.status(201).json(request);
  },
);
