import type { ErrorRequestHandler, RequestHandler } from 'express';

import { HttpError } from '../lib/http-error';

/** Unknown routes answer with JSON too, so the app always gets a message. */
export const notFoundHandler: RequestHandler = (req, res) => {
  res.status(404).json({ message: `Route ${req.method} ${req.path} not found.` });
};

/** MongoDB unique-index violation (e.g. two sign-ups with the same email at once). */
function duplicateKeyMessage(err: unknown): string | null {
  if (typeof err !== 'object' || err === null || (err as { code?: unknown }).code !== 11000) {
    return null;
  }
  const fields = Object.keys((err as { keyPattern?: object }).keyPattern ?? {});
  if (fields.includes('email')) return 'An account with this email already exists.';
  if (fields.includes('studentId')) return 'This ENT ID is already in use.';
  return 'This value is already in use.';
}

/**
 * Turns every error into `{ "message": ... }` with the right status (plus the
 * machine-readable `code` and the extra fields of an HttpError, such as an
 * import's `problems` or a 429's `retryAfter`).
 * Unexpected errors are logged and hidden behind a generic message.
 */
// Express recognises error handlers by their 4 parameters, so `_next` must stay.
export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof HttpError) {
    res.status(err.status).json({
      message: err.message,
      ...(err.code ? { code: err.code } : {}),
      ...err.details,
    });
    return;
  }

  const duplicate = duplicateKeyMessage(err);
  if (duplicate) {
    res.status(409).json({ message: duplicate });
    return;
  }

  // Errors from express.json(): malformed JSON (400), body too large (413)...
  const status = (err as { status?: unknown })?.status;
  if (typeof status === 'number' && status >= 400 && status < 500) {
    res.status(status).json({
      message: status === 400 ? 'Malformed request body.' : 'Request rejected.',
    });
    return;
  }

  console.error(err);
  res.status(500).json({ message: 'Something went wrong. Please try again.' });
};
