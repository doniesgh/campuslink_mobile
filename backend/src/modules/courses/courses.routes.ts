import { Router } from 'express';

import { validateBody } from '../../lib/validate';
import { currentUserId, requireAuth } from '../../middleware/require-auth';
import {
  attendanceSchema,
  submissionSchema,
  type AttendanceInput,
  type SubmissionInput,
} from './courses.schemas';
import * as courses from './courses.service';

/** Routes under /api/courses. Every route needs a signed-in student. */
export const coursesRouter = Router();
coursesRouter.use(requireAuth);

/** The student's courses (sent as a plain array). */
coursesRouter.get('/', async (_req, res) => {
  res.json(await courses.listCourses(currentUserId(res)));
});

// (The `as string` casts: with a middleware before the handler, Express's
// types no longer infer the route parameters.)

coursesRouter.put('/:courseId/attendance', validateBody(attendanceSchema), async (req, res) => {
  const { present } = req.body as AttendanceInput;
  await courses.setAttendance(currentUserId(res), req.params.courseId as string, present);
  res.status(204).end();
});

/** Answers `{ url }`, a link to the document. */
coursesRouter.post('/resources/:resourceId/download', async (req, res) => {
  res.json(await courses.downloadResource(req.params.resourceId));
});

coursesRouter.post(
  '/assignments/:assignmentId/submission',
  validateBody(submissionSchema),
  async (req, res) => {
    const assignmentId = req.params.assignmentId as string;
    const { repoUrl } = req.body as SubmissionInput;
    const submission = await courses.submitAssignment(currentUserId(res), assignmentId, repoUrl);
    res.status(201).json(submission);
  },
);
