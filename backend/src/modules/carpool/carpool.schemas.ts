import { z } from 'zod';

// Messages are shown as-is in the app, so they are written for students.

export const reserveSeatsSchema = z.object({
  seatIds: z
    .array(z.string({ error: 'Choose a valid seat' }).trim().min(1, 'Choose a valid seat'), {
      error: 'Choose at least one seat',
    })
    .min(1, 'Choose at least one seat')
    .max(10, 'You can book at most 10 seats at once')
    // The same seat twice is the same reservation.
    .transform((ids) => [...new Set(ids)]),
});

export type ReserveSeatsInput = z.infer<typeof reserveSeatsSchema>;
