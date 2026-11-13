import type { RequestHandler } from 'express';
import type { z, ZodType } from 'zod';

import { unprocessable } from './http-error';

/** The `code` of every body or query refused by its schema. */
export const VALIDATION_ERROR = 'VALIDATION_ERROR';

const invalid = (error: z.ZodError) =>
  unprocessable(error.issues[0]?.message ?? 'Invalid data.', undefined, VALIDATION_ERROR);

/**
 * Validates `req.body` against [schema] and replaces it with the parsed
 * (trimmed, normalised) value. Invalid bodies get a 422
 * `{ message, code: 'VALIDATION_ERROR' }` with the first problem as the
 * message, which the app displays as-is.
 */
export const validateBody =
  (schema: ZodType): RequestHandler =>
  (req, _res, next) => {
    const result = schema.safeParse(req.body ?? {});
    if (!result.success) {
      next(invalid(result.error));
      return;
    }
    req.body = result.data;
    next();
  };

/**
 * Validates `req.query` like `validateBody` does for bodies: 422 with the
 * first problem as the message. (Express 5 makes `req.query` read-only, so
 * the parsed value is returned instead of replacing it.)
 */
export function parseQuery<S extends ZodType>(schema: S, query: unknown): z.output<S> {
  const result = schema.safeParse(query ?? {});
  if (!result.success) throw invalid(result.error);
  return result.data;
}
