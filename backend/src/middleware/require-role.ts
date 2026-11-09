import type { RequestHandler, Response } from 'express';

import { forbidden, unauthorized } from '../lib/http-error';
import { UserModel, type UserRole } from '../modules/users/user.model';
import { currentUserId } from './require-auth';

/**
 * Lets only the users whose role is one of [roles] through. Goes after
 * [requireAuth]. The role is read from the database on every request (it is
 * not in the token), so a demoted admin loses access at once.
 *
 * Answers 401 for a valid token of a deleted account, 403 with [message] for
 * any other role (by default "Only administrators can do this.").
 */
export const requireRole =
  (roles: readonly UserRole[], message?: string): RequestHandler =>
  async (_req, res, next) => {
    const user = await UserModel.findById(currentUserId(res)).select('role');
    if (!user) throw unauthorized();
    if (!roles.includes(user.role)) throw forbidden(message);
    res.locals.role = user.role;
    next();
  };

/** The signed-in user's role, set by [requireRole]. */
export const currentRole = (res: Response): UserRole => res.locals.role as UserRole;
