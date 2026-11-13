import { Router, type Request, type Response } from 'express';

import { requestContext } from '../../lib/request-context';
import { validateBody } from '../../lib/validate';
import { requireAuth } from '../../middleware/require-auth';
import { requireRole } from '../../middleware/require-role';
import type { AuditAction } from '../admin/audit-log.model';
import { recordAudit } from '../admin/audit.service';
import {
  createSlotSchema,
  updateSlotSchema,
  type CreateSlotInput,
  type UpdateSlotInput,
} from './timetable-admin.schemas';
import * as slots from './timetable-admin.service';
import { notifySlotChange, type SlotChange } from './timetable-notifications';
import type { TimetableSlot } from './timetable.model';

/**
 * Routes under /api/admin/timetable: admins manage the weekly timetable of
 * the class group. Mounted before the /admin router (app.ts). Every change is
 * audited, and the students and teachers are notified.
 */
export const adminTimetableRouter = Router();
adminTimetableRouter.use(requireAuth, requireRole(['admin']));

/** "Algorithmes on Tuesday 08:30–10:00" */
const describe = (s: TimetableSlot) =>
  `${s.course} on ${
    ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][s.weekday - 1]
  } ${s.start}–${s.end}`;

/** Audits [change] and notifies the class group. A failed notification never fails the request. */
async function afterChange(
  req: Request,
  res: Response,
  action: AuditAction,
  summary: string,
  change: SlotChange,
): Promise<void> {
  let notified = 0;
  try {
    notified = await notifySlotChange(change);
  } catch (err) {
    console.error('[timetable] Could not notify the timetable change:', err);
  }
  const slot = change.type === 'updated' ? change.after : change.slot;
  await recordAudit({
    ...requestContext(req, res),
    action,
    summary,
    targetType: null,
    metadata: { slotId: slot.slotId, course: slot.course, weekday: slot.weekday, notified },
  });
}

/** GET /slots: every class of the week, by weekday then start time. */
adminTimetableRouter.get('/slots', async (_req, res) => {
  res.json(await slots.listSlots());
});

/** POST /slots: adds a class (422 invalid, 409 clash with `conflicts`). */
adminTimetableRouter.post('/slots', validateBody(createSlotSchema), async (req, res) => {
  const slot = await slots.createSlot(req.body as CreateSlotInput);
  await afterChange(req, res, 'timetable.slot.create', `Added ${describe(slot)}`, {
    type: 'created',
    slot,
  });
  res.status(201).json(slots.toSlotJson(slot));
});

/** PATCH /slots/:slotId: changes the fields sent (422, 409 like POST; 404 unknown class). */
adminTimetableRouter.patch('/slots/:slotId', validateBody(updateSlotSchema), async (req, res) => {
  const { before, after } = await slots.updateSlot(
    String(req.params.slotId),
    req.body as UpdateSlotInput,
  );
  await afterChange(req, res, 'timetable.slot.update', `Changed ${describe(after)}`, {
    type: 'updated',
    before,
    after,
  });
  res.json(slots.toSlotJson(after));
});

/** DELETE /slots/:slotId: removes a class (204; 404 unknown class). */
adminTimetableRouter.delete('/slots/:slotId', async (req, res) => {
  const slot = await slots.deleteSlot(String(req.params.slotId));
  await afterChange(req, res, 'timetable.slot.delete', `Removed ${describe(slot)}`, {
    type: 'deleted',
    slot,
  });
  res.status(204).end();
});
