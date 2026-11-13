import { Router, type Request } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  lostItemRequestSchema,
  publishIdeaSchema,
  publishLostItemSchema,
  updateLostItemSchema,
  type LostItemRequestInput,
  type PublishIdeaInput,
  type PublishLostItemInput,
  type UpdateLostItemInput,
} from './forum.schemas';
import * as forum from './forum.service';

/** Routes under /api/forum. Every route needs a signed-in student. */
export const forumRouter = Router();
forumRouter.use(requireAuth);

forumRouter.get('/highlights', async (_req, res) => {
  res.json(await forum.listHighlights(currentUserId(res)));
});

/** The board, with `isMine` / `canManage` for the signed-in user. */
forumRouter.get('/lost-items', async (_req, res) => {
  res.json(await forum.listLostItems(currentUserId(res)));
});

/** Publishes a lost or found notice. Answers 201 with the created item. */
forumRouter.post('/lost-items', validateBody(publishLostItemSchema), async (req, res) => {
  const input = req.body as PublishLostItemInput;
  res.status(201).json(await forum.publishLostItem(currentUserId(res), input));
});

/**
 * Edits a notice and/or sets its `status` ('active' | 'resolved'). Its
 * reporter or an admin only (403), 404 unknown. Answers the edited item.
 */
forumRouter.patch(
  '/lost-items/:id',
  validateBody(updateLostItemSchema),
  async (req: Request<{ id: string }>, res) => {
    const input = req.body as UpdateLostItemInput;
    res.json(await forum.updateLostItem(currentUserId(res), req.params.id, input));
  },
);

/** Deletes a notice (and the requests about it). Its reporter or an admin only. 204. */
forumRouter.delete('/lost-items/:id', async (req: Request<{ id: string }>, res) => {
  await forum.deleteLostItem(currentUserId(res), req.params.id);
  res.status(204).end();
});

/**
 * "Possible matches": `{ items: [{ item, score, reason, reasons, ai }], ai, model }`.
 * Rules, re-ranked by the AI when it is configured (rules only if it fails).
 */
forumRouter.get('/lost-items/:id/matches', async (req: Request<{ id: string }>, res) => {
  res.json(await forum.findLostItemMatches(currentUserId(res), req.params.id));
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
