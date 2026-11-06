import { Router } from 'express';

import { validateBody } from '../../lib/validate';
import { authRateLimit } from '../../middleware/rate-limit';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  forgotPasswordSchema,
  loginSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
  verifyEmailSchema,
  type LoginInput,
  type RegisterInput,
  type ResetPasswordInput,
} from './auth.schemas';
import * as auth from './auth.service';

/** Routes under /api/auth. Bodies are validated (and normalised) before reaching the service. */
export const authRouter = Router();

authRouter.post('/register', authRateLimit, validateBody(registerSchema), async (req, res) => {
  res.status(201).json(await auth.register(req.body as RegisterInput));
});

authRouter.post('/login', authRateLimit, validateBody(loginSchema), async (req, res) => {
  res.json(await auth.login(req.body as LoginInput));
});

authRouter.post('/refresh', validateBody(refreshSchema), async (req, res) => {
  res.json(await auth.refresh((req.body as { refreshToken: string }).refreshToken));
});

authRouter.post('/logout', validateBody(refreshSchema), async (req, res) => {
  await auth.logout((req.body as { refreshToken: string }).refreshToken);
  res.status(204).end();
});

authRouter.post(
  '/forgot-password',
  authRateLimit,
  validateBody(forgotPasswordSchema),
  async (req, res) => {
    await auth.forgotPassword((req.body as { email: string }).email);
    res.json({ message: 'If an account exists for this email, a 6-digit code is on its way.' });
  },
);

authRouter.post(
  '/reset-password',
  authRateLimit,
  validateBody(resetPasswordSchema),
  async (req, res) => {
    await auth.resetPassword(req.body as ResetPasswordInput);
    res.json({ message: 'Password updated. Sign in with your new password.' });
  },
);

authRouter.post(
  '/verify-email',
  authRateLimit,
  requireAuth,
  validateBody(verifyEmailSchema),
  async (req, res) => {
    const user = await auth.verifyEmail(currentUserId(res), (req.body as { code: string }).code);
    res.json({ user });
  },
);

authRouter.post('/resend-verification', authRateLimit, requireAuth, async (_req, res) => {
  await auth.resendVerification(currentUserId(res));
  res.status(204).end();
});
