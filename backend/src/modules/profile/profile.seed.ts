import type { Types } from 'mongoose';

import { StudentProfileModel, type ProfileData } from './profile.model';

/**
 * The values of the app's MockProfileRepository. Credits, rank and honours
 * are not stored: they come from the demo transcript (see profile.service.ts).
 */
export const DEMO_PROFILE: ProfileData = {
  yearOfStudy: 4,
  program: 'Software Engineering',
  programShort: 'Software Eng.',
  classGroup: 'BI',
  campus: 'ESPRIT Ghazela',
  campusLocation: 'Ghazela Technopark',
  gpa: 3.72,
  isOnCampus: true,
  isVerified: true,
  nfcReady: true,
  hasEspritKey: true,
  unreadNotifications: 3,
  hasCarpoolActivity: true,
};

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Must be idempotent (safe to run again).
 */
export async function seedProfile(demoUserId: Types.ObjectId): Promise<void> {
  await StudentProfileModel.findOneAndUpdate(
    { userId: demoUserId },
    { $set: DEMO_PROFILE },
    { upsert: true, runValidators: true },
  );
}
