import { z } from 'zod';

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
