import type { RequestHandler, Response } from 'express';

import { unauthorized } from '../lib/http-error';
import { verifyAccessToken } from '../modules/auth/tokens';

/**
 * Requires `Authorization: Bearer <access token>`. On failure answers 401,
 * which makes the app refresh its token and retry once.
 */
export const requireAuth: RequestHandler = (req, res, next) => {
  const [scheme, token] = (req.get('authorization') ?? '').split(' ');
  const userId = scheme === 'Bearer' && token ? verifyAccessToken(token) : null;
  if (!userId) {
    next(unauthorized());
    return;
  }
  res.locals.userId = userId;
  next();
};

/** The signed-in user's id, set by [requireAuth]. */
export const currentUserId = (res: Response): string => res.locals.userId as string;
