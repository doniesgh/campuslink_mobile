import type { Types } from 'mongoose';

import { DEMO_COURSES, DEMO_PRESENT_COURSE_IDS } from './courses.data';
import { CourseAttendanceModel, CourseModel, CourseResourceModel } from './courses.model';

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Must be idempotent (safe to run again).
 *
 * Writes the course catalog (shared by every student) and resets the demo
 * student's attendance to the app mock's. Submissions are left alone.
 */
export async function seedCourses(demoUserId: Types.ObjectId): Promise<void> {
  const courseIds = DEMO_COURSES.map((c) => c._id);
  const resourceIds = DEMO_COURSES.flatMap((c) => c.resources.map((r) => r._id));

  await CourseModel.bulkWrite(
    DEMO_COURSES.map(({ resources: _resources, ...course }, position) => ({
      replaceOne: { filter: { _id: course._id }, replacement: { ...course, position }, upsert: true },
    })),
  );
  await CourseResourceModel.bulkWrite(
    DEMO_COURSES.flatMap((course) =>
      course.resources.map((resource, position) => ({
        replaceOne: {
          filter: { _id: resource._id },
          replacement: { ...resource, courseId: course._id, position },
          upsert: true,
        },
      })),
    ),
  );
  // Whatever an older seed left behind.
  await CourseModel.deleteMany({ _id: { $nin: courseIds } });
  await CourseResourceModel.deleteMany({ _id: { $nin: resourceIds } });

  await CourseAttendanceModel.bulkWrite(
    courseIds.map((courseId) => ({
      updateOne: {
        filter: { userId: demoUserId, courseId },
        update: { $set: { present: DEMO_PRESENT_COURSE_IDS.includes(courseId) } },
        upsert: true,
      },
    })),
  );
}
