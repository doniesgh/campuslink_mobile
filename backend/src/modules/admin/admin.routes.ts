import { Router, type Request, type Response } from 'express';

import { parseQuery, validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import { requireRole } from '../../middleware/require-role';
import {
  auditQuerySchema,
  createUserSchema,
  importUsersSchema,
  listUsersQuerySchema,
  updateUserSchema,
  type CreateUserInput,
  type ImportUsersInput,
  type UpdateUserInput,
} from './admin.schemas';
import * as adminUsers from './admin-users.service';
import * as audit from './audit.service';
import { importUsers } from './user-import.service';

/**
 * Routes under /api/admin. Every route needs a signed-in admin: the role is
 * read from the database on each request (403 for anyone else).
 */
export const adminRouter = Router();
adminRouter.use(requireAuth, requireRole(['admin']));

/** The acting admin and their IP address ("::ffff:127.0.0.1" is stored as "127.0.0.1"). */
function adminContext(req: Request, res: Response): adminUsers.AdminContext {
  return { actorId: currentUserId(res), ip: req.ip?.replace(/^::ffff:/, '') ?? null };
}

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
  res.status(201).json(await adminUsers.createUser(input, adminContext(req, res)));
});

/** Creates many accounts at once, all or nothing (or only checks them with `dryRun: true`). */
adminRouter.post('/users/import', validateBody(importUsersSchema), async (req, res) => {
  const result = await importUsers(req.body as ImportUsersInput, adminContext(req, res));
  res.status(result.dryRun ? 200 : 201).json(result);
});

adminRouter.patch(
  '/users/:id',
  validateBody(updateUserSchema),
  async (req: Request<{ id: string }>, res) => {
    const input = req.body as UpdateUserInput;
    res.json(await adminUsers.updateUser(req.params.id, input, adminContext(req, res)));
  },
);

adminRouter.delete('/users/:id', async (req: Request<{ id: string }>, res) => {
  await adminUsers.deleteUser(req.params.id, adminContext(req, res));
  res.status(204).end();
});

adminRouter.get('/audit', async (req, res) => {
  res.json(await audit.listAudit(parseQuery(auditQuerySchema, req.query)));
});

adminRouter.get('/audit/actions', async (_req, res) => {
  res.json(await audit.listAuditActions());
});
