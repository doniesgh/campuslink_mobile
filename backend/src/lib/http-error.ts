/**
 * An error with an HTTP status. The error handler sends it as
 * `{ "message": ... }`, the format the mobile app shows to the user.
 */
export class HttpError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
  }
}

export const badRequest = (message: string) => new HttpError(400, message);

export const unauthorized = (message = 'Invalid credentials or expired session.') =>
  new HttpError(401, message);

export const notFound = (message = 'Not found.') => new HttpError(404, message);

export const conflict = (message: string) => new HttpError(409, message);
