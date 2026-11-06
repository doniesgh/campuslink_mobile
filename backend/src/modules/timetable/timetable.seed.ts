import type { Types } from 'mongoose';

import { CLASS_GROUP, DEMO_TIMETABLE } from './timetable.data';
import { TimetableTemplateModel } from './timetable.model';

/**
 * Demo data for this module. Called by `npm run seed` with the demo
 * student's id. Must be idempotent (safe to run again).
 *
 * The timetable is shared by the whole class group (the demo student
 * included), so this only (re)writes the group's weekly template.
 */
export async function seedTimetable(_demoUserId: Types.ObjectId): Promise<void> {
  await TimetableTemplateModel.replaceOne(
    { classGroup: CLASS_GROUP },
    { classGroup: CLASS_GROUP, slots: DEMO_TIMETABLE },
    { upsert: true },
  );
}
