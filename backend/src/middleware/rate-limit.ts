import { rateLimit } from 'express-rate-limit';

import { isProd, isTest } from '../config/env';

/**
 * Slows down password guessing and code brute-forcing on the auth routes.
 * Generous outside production so local testing is not blocked; off in tests.
 */
export const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: isProd ? 20 : 300,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  skip: () => isTest,
  message: { message: 'Too many attempts. Please wait a few minutes and try again.' },
});
