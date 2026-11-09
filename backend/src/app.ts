import cors from 'cors';
import express, { Router } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { env, isProd, isTest } from './config/env';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { adminRouter } from './modules/admin/admin.routes';
import { authRouter } from './modules/auth/auth.routes';
import { carpoolRouter } from './modules/carpool/carpool.routes';
import { coursesRouter } from './modules/courses/courses.routes';
import { forumRouter } from './modules/forum/forum.routes';
import { gradesRouter } from './modules/grades/grades.routes';
import { jobsRouter } from './modules/jobs/jobs.routes';
import { notificationsRouter } from './modules/notifications/notifications.routes';
import { profileRouter } from './modules/profile/profile.routes';
import { pushRouter } from './modules/push/push.routes';
import { timetableRouter } from './modules/timetable/timetable.routes';
import { usersRouter } from './modules/users/users.routes';

/** Builds the Express app (no network or database side effects: tests use it directly). */
export function createApp() {
  const app = express();
  // Behind a proxy (Render), req.ip must come from X-Forwarded-For: otherwise
  // every user shares the proxy's IP and its auth rate limit.
  if (env.TRUST_PROXY > 0) app.set('trust proxy', env.TRUST_PROXY);

  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN.split(',') }));
  // A user import (up to 1000 lines) is the only request bigger than 100 kB.
  app.use('/api/admin/users/import', express.json({ limit: '1mb' }));
  app.use(express.json({ limit: '100kb' }));
  if (!isTest) app.use(morgan(isProd ? 'combined' : 'dev'));

  const api = Router();
  api.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });
  api.use('/auth', authRouter);
  api.use('/users', usersRouter);
  api.use('/timetable', timetableRouter);
  api.use('/courses', coursesRouter);
  api.use('/carpool', carpoolRouter);
  api.use('/jobs', jobsRouter);
  api.use('/forum', forumRouter);
  api.use('/grades', gradesRouter);
  api.use('/profile', profileRouter);
  api.use('/notifications', notificationsRouter);
  api.use('/push', pushRouter);
  api.use('/admin', adminRouter);
  app.use('/api', api);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
