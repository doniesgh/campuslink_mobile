import { Router, type Request } from 'express';

import { aiModel, isAiConfigured } from '../../lib/openrouter';
import { requestContext } from '../../lib/request-context';
import { parseQuery, validateBody } from '../../lib/validate';
import { userLimit } from '../../middleware/rate-limit';
import { requireAuth } from '../../middleware/require-auth';
import { requireRole } from '../../middleware/require-role';
import {
  auditQuerySchema,
  createUserSchema,
  importAssistSchema,
  importUsersSchema,
  listUsersQuerySchema,
  updateUserSchema,
  type CreateUserInput,
  type ImportAssistInput,
  type ImportUsersInput,
  type UpdateUserInput,
} from './admin.schemas';
import * as adminUsers from './admin-users.service';
import * as audit from './audit.service';
import { assistImport } from './import-assist.service';
import { importUsers } from './user-import.service';

/**
 * Routes under /api/admin. Every route needs a signed-in admin: the role is
 * read from the database on each request (403 for anyone else).
 */
export const adminRouter = Router();
adminRouter.use(requireAuth, requireRole(['admin']));

adminRouter.get('/users', async (req, res) => {
  res.json(await adminUsers.listUsers(parseQuery(listUsersQuerySchema, req.query)));
});

adminRouter.get('/users/stats', async (_req, res) => {
  res.json(await adminUsers.userStats());
});

adminRouter.get('/users/:id', async (req: Request<{ id: string }>, res) => {
  res.json(await adminUsers.getUser(req.params.id));
});

adminRouter.post('/users', validateBody(createUserSchema), async (req, res) => {
  const input = req.body as CreateUserInput;
  res.status(201).json(await adminUsers.createUser(input, requestContext(req, res)));
});

/** Creates many accounts at once, all or nothing (or only checks them with `dryRun: true`). */
adminRouter.post('/users/import', validateBody(importUsersSchema), async (req, res) => {
  const result = await importUsers(req.body as ImportUsersInput, requestContext(req, res));
  res.status(result.dryRun ? 200 : 201).json(result);
});

/** Whether the app can offer "Read with AI" on the import screen. */
adminRouter.get('/users/import/assist', (_req, res) => {
  const available = isAiConfigured();
  res.json({ available, model: available ? aiModel() : null });
});

/** Asks the AI how an import file is laid out (see import-assist.service.ts). Nothing is imported. */
adminRouter.post(
  '/users/import/assist',
  userLimit({
    name: 'import-assist',
    limit: 20,
    windowMs: 60 * 60 * 1000,
    message: 'You asked the AI to read files too often. Try again in an hour.',
  }),
  validateBody(importAssistSchema),
  async (req, res) => {
    res.json(await assistImport(req.body as ImportAssistInput, requestContext(req, res)));
  },
);

adminRouter.patch(
  '/users/:id',
  validateBody(updateUserSchema),
  async (req: Request<{ id: string }>, res) => {
    const input = req.body as UpdateUserInput;
    res.json(await adminUsers.updateUser(req.params.id, input, requestContext(req, res)));
  },
);

adminRouter.delete('/users/:id', async (req: Request<{ id: string }>, res) => {
  await adminUsers.deleteUser(req.params.id, requestContext(req, res));
  res.status(204).end();
});

adminRouter.get('/audit', async (req, res) => {
  res.json(await audit.listAudit(parseQuery(auditQuerySchema, req.query)));
});

adminRouter.get('/audit/actions', async (_req, res) => {
  res.json(await audit.listAuditActions());
});
