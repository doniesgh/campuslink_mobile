import type { RequestHandler } from 'express';
import type { ZodType } from 'zod';

import { HttpError } from './http-error';

/**
 * Validates `req.body` against [schema] and replaces it with the parsed
 * (trimmed, normalised) value. Invalid bodies get a 422 with the first
 * problem as the message, which the app displays as-is.
 */
export const validateBody =
  (schema: ZodType): RequestHandler =>
  (req, _res, next) => {
    const result = schema.safeParse(req.body ?? {});
    if (!result.success) {
      next(new HttpError(422, result.error.issues[0]?.message ?? 'Invalid data.'));
      return;
    }
    req.body = result.data;
    next();
  };
