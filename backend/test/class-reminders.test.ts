import { PushDeviceModel } from '../src/modules/push/push-device.model';
import { setPushSender } from '../src/modules/push/push.service';
import { ClassReminderModel } from '../src/modules/timetable/class-reminder.model';
import {
  CLASS_REMINDERS_CHANNEL,
  sendClassReminders,
} from '../src/modules/timetable/class-reminders';
import { seedTimetable } from '../src/modules/timetable/timetable.seed';
import type { UserRole } from '../src/modules/users/user.model';
import {
  capturePush,
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createStudent,
} from './helpers';

const push = capturePush();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(async () => {
  await clearTestDb();
  push.reset();
});

/**
 * Monday 9 November 2026 at [time] on campus (UTC+1). The demo Monday:
 * Algorithmes 08:30 (lecture), Génie Logiciel 10:15 (lab), NoSQL 13:30
 * (workshop), Réseaux 16:00 (exam).
 */
const monday = (time: string) => new Date(`2026-11-09T${time}:00+01:00`);

/** An account of [role] with a phone registered as [token] (or none). */
async function account(role: UserRole, token?: string) {
  const { user } = await createStudent({ role });
  if (token) await PushDeviceModel.create({ userId: user._id, token, platform: 'android' });
  return user;
}

async function campus() {
  const student = await account('student', 'student-phone');
  await seedTimetable(student._id);
  await account('teacher', 'teacher-phone');
  await account('admin', 'admin-phone');
  await account('alumni', 'alumni-phone');
  await account('student'); // no phone
}

const tokens = () => push.messages.map((m) => m.token).sort();

describe('sendClassReminders', () => {
  test('15 minutes before a class, the students and teachers with a phone are reminded', async () => {
    await campus();

    const run = await sendClassReminders(monday('08:15'));

    expect(run.reminded).toEqual([
      { sessionId: 'algo-cm-2026-11-9', course: 'Algorithmes & Complexité', start: '08:30' },
    ]);
    expect(run.report).toEqual({ devices: 2, sent: 2, failed: 0, removed: 0 });
    // Admins and alumni follow no classes.
    expect(tokens()).toEqual(['student-phone', 'teacher-phone']);
    expect(push.messages[0]).toEqual({
      token: expect.any(String),
      notification: {
        title: 'Algorithmes & Complexité',
        body: 'Lecture in 15 min · 08:30–10:00 · Amphi A',
      },
      data: { notificationId: '', category: 'academic', destination: 'timetable', targetId: '' },
      android: {
        priority: 'high',
        notification: { tag: 'class-algo-cm-2026-11-9', channelId: CLASS_REMINDERS_CHANNEL },
      },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  });

  test('each class is reminded once, whatever the number of checks', async () => {
    await campus();

    await sendClassReminders(monday('08:15'));
    const again = await sendClassReminders(monday('08:16'));
    const later = await sendClassReminders(monday('08:29'));

    expect(again.reminded).toEqual([]);
    expect(later.reminded).toEqual([]);
    expect(push.messages).toHaveLength(2);
    expect(await ClassReminderModel.countDocuments()).toBe(1);
  });

  test('says how long is left when the check comes late, and names the kind', async () => {
    await campus();

    await sendClassReminders(monday('10:05'));
    await sendClassReminders(monday('15:57'));

    expect(push.messages.map((m) => m.notification.body)).toEqual([
      'Lab in 10 min · 10:15–12:15 · Lab 204',
      'Lab in 10 min · 10:15–12:15 · Lab 204',
      'Exam in 3 min · 16:00–18:00 · Grand Amphi C',
      'Exam in 3 min · 16:00–18:00 · Grand Amphi C',
    ]);
  });

  test('nothing too early, once started, or on a day without classes', async () => {
    await campus();

    await sendClassReminders(monday('08:00')); // 30 min before
    await sendClassReminders(monday('08:30')); // starting now
    await sendClassReminders(monday('09:00')); // during, next one at 10:15
    await sendClassReminders(new Date('2026-11-14T09:45:00+01:00')); // Saturday

    expect(push.messages).toEqual([]);
    expect(await ClassReminderModel.countDocuments()).toBe(0);
  });

  test('a class is not used up while nobody can be reminded', async () => {
    const admin = await account('admin', 'admin-phone');
    await seedTimetable(admin._id);

    const nobody = await sendClassReminders(monday('08:15'));
    await account('student', 'student-phone');
    const then = await sendClassReminders(monday('08:20'));

    expect(nobody.reminded).toEqual([]);
    expect(then.reminded.map((r) => r.sessionId)).toEqual(['algo-cm-2026-11-9']);
    expect(push.messages[0]?.notification.body).toBe('Lecture in 10 min · 08:30–10:00 · Amphi A');
  });

  test('a phone Firebase no longer knows is removed', async () => {
    await campus();
    push.errors['student-phone'] = 'messaging/registration-token-not-registered';

    const run = await sendClassReminders(monday('08:15'));

    expect(run.report).toEqual({ devices: 2, sent: 1, failed: 0, removed: 1 });
    expect(await PushDeviceModel.exists({ token: 'student-phone' })).toBeNull();
  });

  test('push off: nothing is read, sent or claimed', async () => {
    await campus();
    setPushSender(null);
    try {
      const run = await sendClassReminders(monday('08:15'));

      expect(run.reminded).toEqual([]);
      expect(await ClassReminderModel.countDocuments()).toBe(0);
    } finally {
      capturePush(push);
    }
  });
});
