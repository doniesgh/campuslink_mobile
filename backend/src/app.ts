import cors from 'cors';
import express, { Router } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { env, isProd, isTest } from './config/env';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { authRouter } from './modules/auth/auth.routes';
import { usersRouter } from './modules/users/users.routes';

/** Builds the Express app (no network or database side effects: tests use it directly). */
export function createApp() {
  const app = express();

  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',') }));
  app.use(express.json({ limit: '100kb' }));
  if (!isTest) app.use(morgan(isProd ? 'combined' : 'dev'));

  const api = Router();
  api.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });
  api.use('/auth', authRouter);
  api.use('/users', usersRouter);
  app.use('/api', api);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
