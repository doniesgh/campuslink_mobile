import { z } from 'zod';

// Messages are shown as-is in the app, so they are written for students.

const PROOF_MISSING = 'Please add a detail that identifies the item.';

export const lostItemRequestSchema = z.object({
  proof: z
    .string({ error: PROOF_MISSING })
    .trim()
    .min(1, PROOF_MISSING)
    .max(500, 'Keep the detail under 500 characters.'),
});

export type LostItemRequestInput = z.infer<typeof lostItemRequestSchema>;
