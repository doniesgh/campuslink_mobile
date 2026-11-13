/**
 * Machine-readable error codes sent next to the message, so the app can react
 * to (or translate) an error without parsing its English text. Optional: most
 * errors have none, and the app then shows the message as it is.
 *
 * Known codes (add new ones here, in SCREAMING_SNAKE_CASE, and in docs/api.md):
 * - `VALIDATION_ERROR`: a body or query refused by its Zod schema (422).
 * - `TOO_MANY_REQUESTS`: a rate limit was hit (429, with `retryAfter` seconds).
 * - `AI_UNAVAILABLE`, `AI_NO_CREDITS`, `AI_BUSY`, `AI_FAILED`: the AI service
 *   (lib/openrouter.ts) is off or could not answer.
 */
export type ErrorCode = string;

/**
 * An error with an HTTP status. The error handler sends it as
 * `{ "message": ..., "code"?: ..., ...details }`: the message is what the
 * mobile app shows to the user, [code] an optional machine-readable code (see
 * [ErrorCode]), and [details] extra fields (e.g. the `problems` of a user
 * import, the `retryAfter` of a 429).
 *
 * `new HttpError(422, 'Enter a name', undefined, 'VALIDATION_ERROR')`
 */
export class HttpError extends Error {
  readonly status: number;
  readonly details?: Record<string, unknown>;
  readonly code?: ErrorCode;

  constructor(
    status: number,
    message: string,
    details?: Record<string, unknown>,
    code?: ErrorCode,
  ) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.details = details;
    this.code = code;
  }
}

export const badRequest = (message: string, code?: ErrorCode) =>
  new HttpError(400, message, undefined, code);

export const unauthorized = (
  message = 'Invalid credentials or expired session.',
  code?: ErrorCode,
) => new HttpError(401, message, undefined, code);

/** Signed in, but not allowed (e.g. an /admin route used by someone who isn't an admin). */
export const forbidden = (message = 'Only administrators can do this.', code?: ErrorCode) =>
  new HttpError(403, message, undefined, code);

export const notFound = (message = 'Not found.', code?: ErrorCode) =>
  new HttpError(404, message, undefined, code);

export const conflict = (message: string, code?: ErrorCode) =>
  new HttpError(409, message, undefined, code);

/** Invalid data (422), optionally with extra fields sent next to the message. */
export const unprocessable = (
  message: string,
  details?: Record<string, unknown>,
  code?: ErrorCode,
) => new HttpError(422, message, details, code);

/**
 * Too many requests (429): `{ message, code: 'TOO_MANY_REQUESTS', retryAfter }`.
 * The rate limiters (middleware/rate-limit.ts) also set the `Retry-After` header.
 */
export const tooManyRequests = (message: string, retryAfter: number) =>
  new HttpError(429, message, { retryAfter }, 'TOO_MANY_REQUESTS');
