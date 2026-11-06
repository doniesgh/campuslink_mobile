import bcrypt from 'bcryptjs';

import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';
import { seedCarpool } from '../modules/carpool/carpool.seed';
import { seedCourses } from '../modules/courses/courses.seed';
import { seedForum } from '../modules/forum/forum.seed';
import { seedGrades } from '../modules/grades/grades.seed';
import { seedJobs } from '../modules/jobs/jobs.seed';
import { seedNotifications } from '../modules/notifications/notifications.seed';
import { seedProfile } from '../modules/profile/profile.seed';
import { seedTimetable } from '../modules/timetable/timetable.seed';
import { UserModel } from '../modules/users/user.model';

/**
 * Creates (or resets) the demo student and every module's demo data.
 * Run with: npm run seed (safe to run again: each step is idempotent).
 */
const DEMO = {
  email: 'dony.mansour@campus.test',
  studentId: '211JMT0428',
  displayName: 'Dony Mansour',
  password: 'CampusPulse2026!',
};

const moduleSeeds = {
  timetable: seedTimetable,
  courses: seedCourses,
  carpool: seedCarpool,
  jobs: seedJobs,
  forum: seedForum,
  grades: seedGrades,
  profile: seedProfile,
  notifications: seedNotifications,
};

async function seed(): Promise<void> {
  await connectMongo(env.MONGO_URL);
  const student = await UserModel.findOneAndUpdate(
    { email: DEMO.email },
    {
      $set: {
        studentId: DEMO.studentId,
        displayName: DEMO.displayName,
        passwordHash: await bcrypt.hash(DEMO.password, 10),
        isEmailVerified: true,
      },
    },
    { upsert: true, returnDocument: 'after' },
  );
  if (!student) throw new Error('Could not create the demo student');

  for (const [name, seedModule] of Object.entries(moduleSeeds)) {
    await seedModule(student._id);
    console.info(`  seeded ${name}`);
  }

  console.info('Demo student ready:');
  console.info(`  ENT ID:   ${DEMO.studentId}`);
  console.info(`  Email:    ${DEMO.email}`);
  console.info(`  Password: ${DEMO.password}`);
}

seed()
  .catch((err: unknown) => {
    console.error('Seeding failed:', err);
    process.exitCode = 1;
  })
  .finally(() => disconnectMongo());
