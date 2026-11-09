/**
 * An error with an HTTP status. The error handler sends it as
 * `{ "message": ... }`, the format the mobile app shows to the user, plus
 * the optional [details] fields (e.g. the `problems` of a user import).
 */
export class HttpError extends Error {
  readonly status: number;
  readonly details?: Record<string, unknown>;

  constructor(status: number, message: string, details?: Record<string, unknown>) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.details = details;
  }
}

export const badRequest = (message: string) => new HttpError(400, message);

export const unauthorized = (message = 'Invalid credentials or expired session.') =>
  new HttpError(401, message);

/** Signed in, but not allowed (e.g. an /admin route used by someone who isn't an admin). */
export const forbidden = (message = 'Only administrators can do this.') =>
  new HttpError(403, message);

export const notFound = (message = 'Not found.') => new HttpError(404, message);

export const conflict = (message: string) => new HttpError(409, message);

/** Invalid data (422), optionally with extra fields sent next to the message. */
export const unprocessable = (message: string, details?: Record<string, unknown>) =>
  new HttpError(422, message, details);
