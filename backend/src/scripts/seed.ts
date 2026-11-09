import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';
import { hashPassword } from '../modules/auth/auth.service';
import { seedCarpool } from '../modules/carpool/carpool.seed';
import { seedCourses } from '../modules/courses/courses.seed';
import { seedForum } from '../modules/forum/forum.seed';
import { seedGrades } from '../modules/grades/grades.seed';
import { seedJobs } from '../modules/jobs/jobs.seed';
import { seedNotifications } from '../modules/notifications/notifications.seed';
import { seedProfile } from '../modules/profile/profile.seed';
import { seedTimetable } from '../modules/timetable/timetable.seed';
import { backfillRoles, UserModel, type UserRole } from '../modules/users/user.model';

/**
 * Creates (or resets) the demo student and every module's demo data, the
 * demo admin and a few demo accounts for the admin's user list.
 * Run with: npm run seed (safe to run again: each step is idempotent).
 */
const DEMO = {
  email: 'dony.mansour@campus.test',
  studentId: '211JMT0428',
  displayName: 'Dony Mansour',
  password: 'CampusPulse2026!',
};

/** The demo admin (no ENT ID: staff don't have one). */
const DEMO_ADMIN = {
  email: 'admin@campus.test',
  displayName: 'Campus Admin',
  password: 'CampusPulseAdmin2026!',
};

/** More accounts, so the admin's user list isn't empty. They share the demo student's password. */
const DEMO_ACCOUNTS: { displayName: string; email: string; role: UserRole; studentId?: string }[] =
  [
    { displayName: 'Amira Ben Salah', email: 'amira.bensalah@campus.test', role: 'teacher' },
    { displayName: 'Karim Trabelsi', email: 'karim.trabelsi@campus.test', role: 'teacher' },
    {
      displayName: 'Sarra Mansouri',
      email: 'sarra.mansouri@campus.test',
      role: 'student',
      studentId: '221JMT0101',
    },
    {
      displayName: 'Omar Ferchichi',
      email: 'omar.ferchichi@campus.test',
      role: 'student',
      studentId: '221JMT0102',
    },
    {
      displayName: 'Yasmine Haddad',
      email: 'yasmine.haddad@campus.test',
      role: 'student',
      studentId: '221JMT0103',
    },
    {
      displayName: 'Inès Zouari',
      email: 'ines.zouari@campus.test',
      role: 'student',
      studentId: '221JMT0104',
    },
    {
      displayName: 'Youssef Hammami',
      email: 'youssef.hammami@campus.test',
      role: 'student',
      studentId: '221JMT0105',
    },
    {
      displayName: 'Hélène Gharbi',
      email: 'helene.gharbi@campus.test',
      role: 'student',
      studentId: '221JMT0106',
    },
    { displayName: 'Selim Rekik', email: 'selim.rekik@campus.test', role: 'alumni' },
  ];

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

/**
 * Creates the account with [email], or resets its name, role and password
 * (and ENT ID when given). Verified. Other accounts are never touched.
 */
async function upsertAccount(account: {
  email: string;
  displayName: string;
  role: UserRole;
  passwordHash: string;
  studentId?: string;
}) {
  const { email, ...fields } = account;
  const user = await UserModel.findOneAndUpdate(
    { email },
    { $set: { ...fields, isEmailVerified: true } },
    { upsert: true, returnDocument: 'after' },
  );
  if (!user) throw new Error(`Could not create the demo account ${email}`);
  return user;
}

async function seed(): Promise<void> {
  await connectMongo(env.MONGO_URL);
  await backfillRoles();

  const studentPasswordHash = await hashPassword(DEMO.password);
  const student = await upsertAccount({
    email: DEMO.email,
    studentId: DEMO.studentId,
    displayName: DEMO.displayName,
    role: 'student',
    passwordHash: studentPasswordHash,
  });

  for (const [name, seedModule] of Object.entries(moduleSeeds)) {
    await seedModule(student._id);
    console.info(`  seeded ${name}`);
  }

  await upsertAccount({
    email: DEMO_ADMIN.email,
    displayName: DEMO_ADMIN.displayName,
    role: 'admin',
    passwordHash: await hashPassword(DEMO_ADMIN.password),
  });
  for (const account of DEMO_ACCOUNTS) {
    await upsertAccount({ ...account, passwordHash: studentPasswordHash });
  }
  console.info(`  seeded ${DEMO_ACCOUNTS.length + 1} demo accounts (admin included)`);

  console.info('Demo student ready:');
  console.info(`  ENT ID:   ${DEMO.studentId}`);
  console.info(`  Email:    ${DEMO.email}`);
  console.info(`  Password: ${DEMO.password}`);
  console.info('Demo admin ready:');
  console.info(`  Email:    ${DEMO_ADMIN.email}`);
  console.info(`  Password: ${DEMO_ADMIN.password}`);
}

seed()
  .catch((err: unknown) => {
    console.error('Seeding failed:', err);
    process.exitCode = 1;
  })
  .finally(() => disconnectMongo());
