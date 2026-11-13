import { Router, type Request } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  lostItemRequestSchema,
  publishIdeaSchema,
  publishLostItemSchema,
  type LostItemRequestInput,
  type PublishIdeaInput,
  type PublishLostItemInput,
} from './forum.schemas';
import * as forum from './forum.service';

/** Routes under /api/forum. Every route needs a signed-in student. */
export const forumRouter = Router();
forumRouter.use(requireAuth);

forumRouter.get('/highlights', async (_req, res) => {
  res.json(await forum.listHighlights(currentUserId(res)));
});

forumRouter.get('/lost-items', async (_req, res) => {
  res.json(await forum.listLostItems(currentUserId(res)));
});

/** Publishes a lost or found notice. Answers 201 with the created item. */
forumRouter.post('/lost-items', validateBody(publishLostItemSchema), async (req, res) => {
  const input = req.body as PublishLostItemInput;
  res.status(201).json(await forum.publishLostItem(currentUserId(res), input));
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

forumRouter.get('/ideas', async (_req, res) => {
  res.json(await forum.listIdeas(currentUserId(res)));
});

/** Publishes an idea. Answers 201 with the created post. */
forumRouter.post('/ideas', validateBody(publishIdeaSchema), async (req, res) => {
  const input = req.body as PublishIdeaInput;
  res.status(201).json(await forum.publishIdea(currentUserId(res), input));
});

/** Adds or removes the student's vote. Answers `{ upvotes, isUpvotedByMe }`. */
forumRouter.post('/ideas/:id/upvote', async (req, res) => {
  res.json(await forum.toggleIdeaUpvote(currentUserId(res), req.params.id));
});

/** Deletes the student's own lost-item notice. Answers 204. */
forumRouter.delete('/lost-items/:id', async (req: Request<{ id: string }>, res) => {
  await forum.deleteLostItem(currentUserId(res), req.params.id);
  res.sendStatus(204);
});

/** Deletes the student's own idea. Answers 204. */
forumRouter.delete('/ideas/:id', async (req: Request<{ id: string }>, res) => {
  await forum.deleteIdea(currentUserId(res), req.params.id);
  res.sendStatus(204);
});
