import { z } from 'zod';

import { PUSH_PLATFORMS } from './push-device.model';

// The app sends these bodies on its own, but the messages are still written
// to be read (they end up in the app's logs and in bug reports).

/** FCM tokens are about 160 characters today; this leaves room for longer ones. */
export const MAX_PUSH_TOKEN_LENGTH = 4096;

const TOKEN_MISSING = 'Send the push token of this device';
const TOKEN_TOO_LONG = `The push token is too long (at most ${MAX_PUSH_TOKEN_LENGTH} characters)`;

const pushToken = z
  .string({ error: TOKEN_MISSING })
  .trim()
  .min(1, TOKEN_MISSING)
  .max(MAX_PUSH_TOKEN_LENGTH, TOKEN_TOO_LONG);

/** `PUT /push/devices` */
export const registerDeviceSchema = z.object({
  token: pushToken,
  platform: z.enum(PUSH_PLATFORMS, { error: 'Platform: android or ios' }),
});

/** `DELETE /push/devices` */
export const unregisterDeviceSchema = z.object({ token: pushToken });

/** The optional `pushToken` of `POST /auth/logout` (missing, null or "" for none). */
export const optionalPushToken = z
  .string({ error: 'The push token must be text' })
  .trim()
  .max(MAX_PUSH_TOKEN_LENGTH, TOKEN_TOO_LONG)
  .nullish();

export type RegisterDeviceInput = z.output<typeof registerDeviceSchema>;
export type UnregisterDeviceInput = z.output<typeof unregisterDeviceSchema>;
