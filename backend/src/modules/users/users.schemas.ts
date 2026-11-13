import { z } from 'zod';

import { localeSchema } from '../../lib/i18n';

// Messages are shown as-is in the app.

/**
 * `PATCH /users/me`: what a user may change on their own account. Every field
 * is optional, but at least one must be sent. Other fields (email, role...)
 * are ignored: only an admin changes those.
 *
 * To let users change another field, add it here and apply it in
 * `updateMe()` (users.service.ts).
 */
export const updateMeSchema = z
  .object({
    /** The app's language, used for the emails and notifications the server writes. */
    locale: localeSchema.optional(),
  })
  .refine((input) => Object.values(input).some((value) => value !== undefined), {
    message: "There's nothing to save.",
  });

export type UpdateMeInput = z.output<typeof updateMeSchema>;
