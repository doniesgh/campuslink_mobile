import cors from 'cors';
import express, { Router } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';

import { env, isProd, isTest } from './config/env';
import { errorHandler, notFoundHandler } from './middleware/error-handler';
import { authRouter } from './modules/auth/auth.routes';
import { carpoolRouter } from './modules/carpool/carpool.routes';
import { coursesRouter } from './modules/courses/courses.routes';
import { forumRouter } from './modules/forum/forum.routes';
import { gradesRouter } from './modules/grades/grades.routes';
import { jobsRouter } from './modules/jobs/jobs.routes';
import { notificationsRouter } from './modules/notifications/notifications.routes';
import { profileRouter } from './modules/profile/profile.routes';
import { timetableRouter } from './modules/timetable/timetable.routes';
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
  api.use('/timetable', timetableRouter);
  api.use('/courses', coursesRouter);
  api.use('/carpool', carpoolRouter);
  api.use('/jobs', jobsRouter);
  api.use('/forum', forumRouter);
  api.use('/grades', gradesRouter);
  api.use('/profile', profileRouter);
  api.use('/notifications', notificationsRouter);
  app.use('/api', api);

  app.use(notFoundHandler);
  app.use(errorHandler);
  return app;
}
