import { z } from 'zod';

import { HttpError } from '../../lib/http-error';
import { parseCalendarDate } from './calendar';

const dateMessage = 'Pass the date as YYYY-MM-DD';

/** `?date=YYYY-MM-DD`, parsed into a calendar date. */
export const dateQuerySchema = z.object({
  date: z
    .string({ error: dateMessage })
    .regex(/^\d{4}-\d{2}-\d{2}$/, dateMessage)
    .transform((value, ctx) => {
      const date = parseCalendarDate(value);
      if (!date) {
        ctx.addIssue({ code: 'custom', message: 'This date does not exist' });
        return z.NEVER;
      }
      return date;
    }),
});

/**
 * Validates `req.query` like `validateBody` does for bodies: 422 with the
 * first problem as the message. (Express 5 makes `req.query` read-only, so
 * the parsed value is returned instead of replacing it.)
 */
export function parseQuery<S extends z.ZodType>(schema: S, query: unknown): z.output<S> {
  const result = schema.safeParse(query ?? {});
  if (!result.success) {
    throw new HttpError(422, result.error.issues[0]?.message ?? 'Invalid data.');
  }
  return result.data;
}
