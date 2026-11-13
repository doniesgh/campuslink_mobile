import { Router } from 'express';

import { localeOf } from '../../lib/i18n';
import { requestMeta } from '../../lib/request-context';
import { validateBody } from '../../lib/validate';
import { authIpLimit, authLimit } from '../../middleware/rate-limit';
import {
  forgotPasswordSchema,
  loginSchema,
  logoutSchema,
  refreshSchema,
  registerSchema,
  resetPasswordSchema,
  type LoginInput,
  type LogoutInput,
  type RegisterInput,
  type ResetPasswordInput,
} from './auth.schemas';
import * as auth from './auth.service';

/**
 * Routes under /api/auth. Bodies are validated (and normalised) before
 * reaching the service. Register, login and the password reset are
 * rate-limited per route, IP and email (`authLimit`, before the body is
 * validated) and per IP (`authIpLimit`). Refresh and logout are not.
 */
export const authRouter = Router();

authRouter.post(
  '/register',
  authLimit('register'),
  authIpLimit,
  validateBody(registerSchema),
  async (req, res) => {
    res.status(201).json(await auth.register(req.body as RegisterInput, localeOf(req)));
  },
);

authRouter.post(
  '/login',
  authLimit('login'),
  authIpLimit,
  validateBody(loginSchema),
  async (req, res) => {
    res.json(await auth.login(req.body as LoginInput));
  },
);

authRouter.post('/refresh', validateBody(refreshSchema), async (req, res) => {
  res.json(await auth.refresh((req.body as { refreshToken: string }).refreshToken));
});

authRouter.post('/logout', validateBody(logoutSchema), async (req, res) => {
  const { refreshToken, pushToken } = req.body as LogoutInput;
  await auth.logout(refreshToken, pushToken);
  res.status(204).end();
});

authRouter.post(
  '/forgot-password',
  authLimit('forgot-password'),
  authIpLimit,
  validateBody(forgotPasswordSchema),
  async (req, res) => {
    await auth.forgotPassword((req.body as { email: string }).email);
    res.json({ message: 'If an account exists for this email, a 6-digit code is on its way.' });
  },
);

authRouter.post(
  '/reset-password',
  authLimit('reset-password'),
  authIpLimit,
  validateBody(resetPasswordSchema),
  async (req, res) => {
    await auth.resetPassword(req.body as ResetPasswordInput, requestMeta(req));
    res.json({ message: 'Password updated. Sign in with your new password.' });
  },
);
