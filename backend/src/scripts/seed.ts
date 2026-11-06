import bcrypt from 'bcryptjs';

import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';
import { UserModel } from '../modules/users/user.model';

/**
 * Creates (or resets) the demo student used to sign in from the app.
 * Run with: npm run seed
 */
const DEMO = {
  email: 'dony.mansour@campus.test',
  studentId: '211JMT0428',
  displayName: 'Dony Mansour',
  password: 'CampusPulse2026!',
};

async function seed(): Promise<void> {
  await connectMongo(env.MONGO_URL);
  await UserModel.findOneAndUpdate(
    { email: DEMO.email },
    {
      $set: {
        studentId: DEMO.studentId,
        displayName: DEMO.displayName,
        passwordHash: await bcrypt.hash(DEMO.password, 10),
        isEmailVerified: true,
      },
    },
    { upsert: true },
  );
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
