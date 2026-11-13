import request from 'supertest';

import { createApp } from '../src/app';
import { AuditLogModel } from '../src/modules/admin/audit-log.model';
import { NotificationModel } from '../src/modules/notifications/notification.model';
import { PushDeviceModel } from '../src/modules/push/push-device.model';
import { sendClassReminders } from '../src/modules/timetable/class-reminders';
import type { SlotJson, SlotListJson } from '../src/modules/timetable/timetable-admin.service';
import { TimetableTemplateModel } from '../src/modules/timetable/timetable.model';
import { seedTimetable } from '../src/modules/timetable/timetable.seed';
import type { TimetableWeekJson } from '../src/modules/timetable/timetable.service';
import { UserModel } from '../src/modules/users/user.model';
import {
  capturePush,
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  validationError,
  type TestAccount,
} from './helpers';

const app = createApp();
const push = capturePush();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(async () => {
  await clearTestDb();
  push.reset();
});

const SLOTS = '/api/admin/timetable/slots';
const MEET = 'https://meet.google.com/abc-defg-hij';

/** An admin, with the demo timetable seeded. */
async function seededAdmin(): Promise<TestAccount> {
  const admin = await createAdmin();
  await seedTimetable(admin.user._id);
  return admin;
}

/** A free Saturday morning class (nothing else on Saturdays). */
const saturdayClass = (overrides: Record<string, unknown> = {}) => ({
  weekday: 6,
  start: '09:00',
  end: '11:00',
  course: 'Cloud Computing',
  room: 'Salle C201',
  teacher: 'Dr. Zribi',
  ...overrides,
});

async function create(admin: TestAccount, body: object, status = 201) {
  return request(app).post(SLOTS).set(admin.auth).send(body).expect(status);
}

async function week(auth: TestAccount['auth'], date: string): Promise<TimetableWeekJson> {
  const res = await request(app).get('/api/timetable/week').query({ date }).set(auth).expect(200);
  return res.body as TimetableWeekJson;
}

describe('access', () => {
  test('needs a token', async () => {
    await request(app).get(SLOTS).expect(401);
    await request(app).post(SLOTS).send(saturdayClass()).expect(401);
  });

  test.each(['student', 'teacher', 'alumni', 'company'] as const)(
    '%s accounts get a 403 on every route',
    async (role) => {
      const { auth } = await createStudent({ role });
      const forbidden = { message: 'Only administrators can do this.' };
      expect((await request(app).get(SLOTS).set(auth).expect(403)).body).toEqual(forbidden);
      expect(
        (await request(app).post(SLOTS).set(auth).send(saturdayClass()).expect(403)).body,
      ).toEqual(forbidden);
      await request(app).patch(`${SLOTS}/algo-cm`).set(auth).send({ room: 'X' }).expect(403);
      await request(app).delete(`${SLOTS}/algo-cm`).set(auth).expect(403);
    },
  );
});

describe('GET /api/admin/timetable/slots', () => {
  test('lists the classes of the week by day and time, with unique ids', async () => {
    const admin = await seededAdmin();
    const res = await request(app).get(SLOTS).set(admin.auth).expect(200);
    const list = res.body as SlotListJson;

    expect(list.classGroup).toBe('Tech Track 4BI');
    expect(list.items).toHaveLength(17);
    expect(new Set(list.items.map((s) => s.id)).size).toBe(17);
    expect(list.items[0]).toEqual({
      id: 'algo-cm',
      weekday: 1,
      start: '08:30',
      end: '10:00',
      course: 'Algorithmes & Complexité',
      room: 'Amphi A',
      teacher: 'Prof. Trabelsi',
      kind: 'lecture',
      mode: 'onsite',
      meetUrl: null,
      notes: null,
      coefficient: null,
      lectureNumber: 8,
      lectureCount: 14,
    });
    expect(list.items.at(-1)).toMatchObject({
      id: 'entrepreneuriat',
      weekday: 5,
      room: '',
      mode: 'online',
      meetUrl: 'https://meet.google.com/xqd-fkzw-pnb',
    });
  });

  test('an empty timetable is an empty list', async () => {
    const admin = await createAdmin();
    const res = await request(app).get(SLOTS).set(admin.auth).expect(200);
    expect(res.body).toEqual({ classGroup: 'Tech Track 4BI', items: [] });
  });

  test('classes saved with the same id get unique ids', async () => {
    const admin = await createAdmin();
    const base = { course: 'Algo', room: 'Lab 14', teacher: 'Dr. Fersi', start: '08:30', end: '10:00' };
    await TimetableTemplateModel.create({
      classGroup: 'Tech Track 4BI',
      slots: [
        { slotId: 'algo', weekday: 2, ...base },
        { slotId: 'algo', weekday: 4, ...base },
      ],
    });
    const ids = ((await request(app).get(SLOTS).set(admin.auth).expect(200)).body as SlotListJson)
      .items.map((s) => s.id);
    expect(ids[0]).toBe('algo');
    expect(ids[1]).toMatch(/^algo-[0-9a-f]{4}$/);
    // Saved: the ids stay the same afterwards.
    const again = ((await request(app).get(SLOTS).set(admin.auth).expect(200)).body as SlotListJson)
      .items.map((s) => s.id);
    expect(again).toEqual(ids);
  });
});

describe('POST /api/admin/timetable/slots', () => {
  test('adds a class that students and teachers then see every week', async () => {
    const admin = await seededAdmin();
    const student = await createStudent();
    const teacher = await createStudent({ role: 'teacher' });

    const res = await create(admin, saturdayClass({ kind: 'lab', notes: '  Bring a laptop ' }));
    const slot = res.body as SlotJson;

    expect(slot).toEqual({
      id: expect.stringMatching(/^cloud-computing-[0-9a-f]{4}$/),
      weekday: 6,
      start: '09:00',
      end: '11:00',
      course: 'Cloud Computing',
      room: 'Salle C201',
      teacher: 'Dr. Zribi',
      kind: 'lab',
      mode: 'onsite',
      meetUrl: null,
      notes: 'Bring a laptop',
      coefficient: null,
      lectureNumber: null,
      lectureCount: null,
    });
    for (const { auth } of [student, teacher]) {
      for (const date of ['2026-11-14', '2026-11-21']) {
        const saturday = (await week(auth, date)).days[5]!;
        expect(saturday.sessions).toEqual([
          expect.objectContaining({
            id: `${slot.id}-${date}`,
            course: 'Cloud Computing',
            room: 'Salle C201',
            start: '09:00',
            kind: 'lab',
            mode: 'onsite',
            meetUrl: null,
          }),
        ]);
      }
    }
  });

  test('online classes: the Meet link is required and checked, the room is optional', async () => {
    const admin = await seededAdmin();
    const student = await createStudent();

    const res = await create(
      admin,
      saturdayClass({ mode: 'online', room: '', meetUrl: ` ${MEET} ` }),
    );
    expect(res.body).toMatchObject({ mode: 'online', room: '', meetUrl: MEET });

    const session = (await week(student.auth, '2026-11-14')).days[5]!.sessions[0];
    expect(session).toMatchObject({ mode: 'online', meetUrl: MEET, room: 'Online' });
  });

  test('an on-site class drops the Meet link, and only exams keep a coefficient', async () => {
    const admin = await seededAdmin();
    const lecture = await create(admin, saturdayClass({ meetUrl: MEET, coefficient: 2 }));
    expect(lecture.body).toMatchObject({ mode: 'onsite', meetUrl: null, coefficient: null });

    const exam = await create(
      admin,
      saturdayClass({ start: '14:00', end: '16:00', kind: 'exam', coefficient: 1.5 }),
    );
    expect(exam.body).toMatchObject({ kind: 'exam', coefficient: 1.5 });
  });

  test.each([
    ['no course', { course: '  ' }, 'Enter the course'],
    ['no teacher', { teacher: undefined }, 'Enter the teacher'],
    ['a bad day', { weekday: 8 }, 'Choose a day from Monday to Sunday'],
    ['a bad start', { start: '9:00' }, 'Enter the start time as HH:mm'],
    ['a bad end', { end: '24:00' }, 'Enter the end time as HH:mm'],
    ['an end before the start', { start: '11:00', end: '09:00' }, 'The class must end after it starts'],
    ['an end at the start', { end: '09:00' }, 'The class must end after it starts'],
    ['more than 8 hours', { start: '08:00', end: '16:30' }, 'A class lasts at most 8 hours'],
    ['an on-site class without room', { room: '' }, 'Enter the room of an on-site class'],
    ['a bad kind', { kind: 'seminar' }, 'Kind: choose lecture, lab, exam or workshop'],
    ['a bad mode', { mode: 'hybrid' }, 'Mode: choose onsite or online'],
    [
      'an online class without link',
      { mode: 'online', meetUrl: null },
      'Enter the Google Meet link of an online class',
    ],
    [
      'a Zoom link',
      { mode: 'online', meetUrl: 'https://zoom.us/j/123456' },
      'Enter a Google Meet link, like https://meet.google.com/abc-defg-hij',
    ],
    [
      'a Meet link without https',
      { mode: 'online', meetUrl: 'http://meet.google.com/abc-defg-hij' },
      'Enter a Google Meet link, like https://meet.google.com/abc-defg-hij',
    ],
    ['a zero coefficient', { kind: 'exam', coefficient: 0 }, 'The coefficient must be between 0 and 10'],
  ])('refuses %s (422)', async (_name, overrides, message) => {
    const admin = await seededAdmin();
    const res = await create(admin, saturdayClass(overrides), 422);
    expect(res.body).toEqual(validationError(message));
    expect((await TimetableTemplateModel.findOne().lean())!.slots).toHaveLength(17);
  });
});

describe('conflicts', () => {
  // Monday: Algorithmes 08:30–10:00 in Amphi A with Prof. Trabelsi.
  const monday = (overrides: Record<string, unknown>) =>
    saturdayClass({ weekday: 1, start: '09:00', end: '10:30', ...overrides });

  test('the same room at overlapping times is a 409 with the clashing class', async () => {
    const admin = await seededAdmin();
    const res = await create(admin, monday({ room: 'amphi a ' }), 409);

    expect(res.body).toEqual({
      message: 'This class clashes with another class of the timetable',
      code: 'TIMETABLE_CONFLICT',
      conflicts: [
        {
          reason: 'room',
          slot: expect.objectContaining({
            id: 'algo-cm',
            weekday: 1,
            start: '08:30',
            end: '10:00',
            course: 'Algorithmes & Complexité',
            room: 'Amphi A',
          }),
        },
      ],
    });
    expect((await TimetableTemplateModel.findOne().lean())!.slots).toHaveLength(17);
  });

  test('the same teacher at overlapping times is a 409, even online', async () => {
    const admin = await seededAdmin();
    const res = await create(
      admin,
      monday({ teacher: 'Prof. Trabelsi', mode: 'online', room: '', meetUrl: MEET }),
      409,
    );
    expect(res.body.conflicts).toEqual([
      { reason: 'teacher', slot: expect.objectContaining({ id: 'algo-cm' }) },
    ]);
  });

  test('both reasons are listed', async () => {
    const admin = await seededAdmin();
    const res = await create(admin, monday({ room: 'Amphi A', teacher: 'Prof. Trabelsi' }), 409);
    expect(res.body.conflicts.map((c: { reason: string }) => c.reason)).toEqual(['room', 'teacher']);
  });

  test('back-to-back classes, other days and other rooms are fine', async () => {
    const admin = await seededAdmin();
    await create(admin, monday({ room: 'Amphi A', start: '10:00', end: '10:15' }));
    await create(admin, monday({ weekday: 6, room: 'Amphi A', teacher: 'Prof. Trabelsi' }));
    await create(admin, monday({ room: 'Salle Z', teacher: 'Dr. Other' }));
  });

  test('a class never clashes with itself when it is edited', async () => {
    const admin = await seededAdmin();
    const res = await request(app)
      .patch(`${SLOTS}/algo-cm`)
      .set(admin.auth)
      .send({ start: '08:45', end: '10:15' })
      .expect(200);
    expect(res.body).toMatchObject({ id: 'algo-cm', start: '08:45', end: '10:15' });
  });

  test('moving a class onto another one with the same teacher is a 409', async () => {
    const admin = await seededAdmin();
    // Tuesday: Génie Logiciel 10:15–12:15 with Prof. Ben Ali (Amphi 3B).
    const res = await request(app)
      .patch(`${SLOTS}/genie-logiciel-tp`)
      .set(admin.auth)
      .send({ weekday: 2 })
      .expect(409);
    expect(res.body.code).toBe('TIMETABLE_CONFLICT');
    expect(res.body.conflicts).toEqual([
      { reason: 'teacher', slot: expect.objectContaining({ id: 'genie-logiciel' }) },
    ]);
  });
});

describe('PATCH /api/admin/timetable/slots/:slotId', () => {
  test('changes the fields sent, keeps the others and the id', async () => {
    const admin = await seededAdmin();
    const student = await createStudent();

    const res = await request(app)
      .patch(`${SLOTS}/nosql`)
      .set(admin.auth)
      .send({ mode: 'online', meetUrl: MEET, notes: 'Camera on' })
      .expect(200);

    expect(res.body).toMatchObject({
      id: 'nosql',
      weekday: 1,
      start: '13:30',
      course: 'Bases de Données Avancées (NoSQL)',
      room: 'Salle B12',
      mode: 'online',
      meetUrl: MEET,
      notes: 'Camera on',
    });
    const session = (await week(student.auth, '2026-11-09')).days[0]!.sessions[2];
    expect(session).toMatchObject({ id: 'nosql-2026-11-9', mode: 'online', meetUrl: MEET });
  });

  test('back on site: a room is needed, and the link is dropped', async () => {
    const admin = await seededAdmin();
    const res = await request(app)
      .patch(`${SLOTS}/entrepreneuriat`)
      .set(admin.auth)
      .send({ mode: 'onsite' })
      .expect(422);
    expect(res.body).toEqual(validationError('Enter the room of an on-site class'));

    const ok = await request(app)
      .patch(`${SLOTS}/entrepreneuriat`)
      .set(admin.auth)
      .send({ mode: 'onsite', room: 'Espace Coworking' })
      .expect(200);
    expect(ok.body).toMatchObject({ mode: 'onsite', room: 'Espace Coworking', meetUrl: null });
  });

  test('the result is checked like a new class', async () => {
    const admin = await seededAdmin();
    const res = await request(app)
      .patch(`${SLOTS}/algo-cm`)
      .set(admin.auth)
      .send({ end: '08:00' })
      .expect(422);
    expect(res.body).toEqual(validationError('The class must end after it starts'));
  });

  test('an empty body is a 422, an unknown class a 404', async () => {
    const admin = await seededAdmin();
    const empty = await request(app).patch(`${SLOTS}/algo-cm`).set(admin.auth).send({}).expect(422);
    expect(empty.body).toEqual(validationError('Nothing to update'));

    const unknown = await request(app)
      .patch(`${SLOTS}/nope`)
      .set(admin.auth)
      .send({ room: 'B12' })
      .expect(404);
    expect(unknown.body).toEqual({ message: 'This class is not in the timetable.' });
  });
});

describe('DELETE /api/admin/timetable/slots/:slotId', () => {
  test('removes the class from every week', async () => {
    const admin = await seededAdmin();
    const student = await createStudent();

    await request(app).delete(`${SLOTS}/algo-cm`).set(admin.auth).expect(204);

    const monday = (await week(student.auth, '2026-11-09')).days[0]!;
    expect(monday.sessions.map((s) => s.id)).toEqual([
      'genie-logiciel-tp-2026-11-9',
      'nosql-2026-11-9',
      'cc-reseaux-2026-11-9',
    ]);
    await request(app).delete(`${SLOTS}/algo-cm`).set(admin.auth).expect(404);
  });
});

describe('notifications and audit', () => {
  /** The campus: a French student with a phone, an English teacher, an admin and an alumni. */
  async function campus() {
    const admin = await seededAdmin();
    const student = await createStudent();
    await PushDeviceModel.create({ userId: student.user._id, token: 'student-phone', platform: 'android' });
    const teacher = await createStudent({ role: 'teacher' });
    await UserModel.updateOne({ _id: teacher.user._id }, { locale: 'en' });
    const alumni = await createStudent({ role: 'alumni' });
    return { admin, student, teacher, alumni };
  }

  const notificationsOf = (account: TestAccount) =>
    NotificationModel.find({ userId: account.user._id }).lean();

  test('a new class is announced to students and teachers, in their language', async () => {
    const { admin, student, teacher, alumni } = await campus();

    const slot = (await create(admin, saturdayClass({ mode: 'online', room: '', meetUrl: MEET })))
      .body as SlotJson;
    await push.settle();

    const [fr] = await notificationsOf(student);
    expect(fr).toMatchObject({
      key: `timetable-${slot.id}`,
      category: 'academic',
      label: 'Emploi du temps',
      title: 'Cloud Computing : nouveau cours le samedi, 09:00–11:00',
      body: 'Un nouveau cours est dans ton emploi du temps : **Cloud Computing** le samedi de 09:00 à 11:00, en ligne.',
      isRead: false,
      link: { destination: 'timetable', id: null },
    });
    const [en] = await notificationsOf(teacher);
    expect(en).toMatchObject({
      label: 'Timetable',
      title: 'Cloud Computing: new class on Saturdays, 09:00–11:00',
      body: 'A new class is in your timetable: **Cloud Computing** on Saturdays, 09:00–11:00, online.',
    });
    expect(await notificationsOf(admin)).toEqual([]);
    expect(await notificationsOf(alumni)).toEqual([]);

    // Pushed to the student's phone.
    expect(push.messages.map((m) => [m.token, m.notification.title])).toEqual([
      ['student-phone', 'Cloud Computing : nouveau cours le samedi, 09:00–11:00'],
    ]);
    expect(push.messages[0]!.data).toMatchObject({ category: 'academic', destination: 'timetable' });

    const [entry] = await AuditLogModel.find().lean();
    expect(entry).toMatchObject({
      action: 'timetable.slot.create',
      summary: 'Added Cloud Computing on Saturday 09:00–11:00',
      targetType: null,
      metadata: { slotId: slot.id, course: 'Cloud Computing', weekday: 6, notified: 2 },
    });
  });

  test('a change replaces the notification about the same class', async () => {
    const { admin, student, teacher } = await campus();

    await request(app).patch(`${SLOTS}/algo-cm`).set(admin.auth).send({ room: 'Amphi B' }).expect(200);
    await request(app)
      .patch(`${SLOTS}/algo-cm`)
      .set(admin.auth)
      .send({ start: '08:00', end: '09:30' })
      .expect(200);

    const mine = await notificationsOf(student);
    expect(mine).toHaveLength(1);
    expect(mine[0]).toMatchObject({
      key: 'timetable-algo-cm',
      title: 'Algorithmes & Complexité : horaire changé 08:30 → 08:00 (lundi)',
      body: 'Désormais, ton cours a lieu le lundi de 08:00 à 09:30, en salle Amphi B.',
    });
    const [en] = await notificationsOf(teacher);
    expect(en).toMatchObject({
      title: 'Algorithmes & Complexité: time changed 08:30 → 08:00 (Mondays)',
      body: 'From now on, your class takes place on Mondays, 08:00–09:30, in room Amphi B.',
    });
    expect(await AuditLogModel.countDocuments({ action: 'timetable.slot.update' })).toBe(2);
  });

  test('room, move, online and removal texts', async () => {
    const { admin, teacher } = await campus();
    const latest = async () => (await notificationsOf(teacher)).at(-1);

    await request(app).patch(`${SLOTS}/algo-cm`).set(admin.auth).send({ room: 'Amphi B' });
    expect(await latest()).toMatchObject({
      title: 'Algorithmes & Complexité: room changed Amphi A → Amphi B (Mondays, 08:30)',
      body: 'Your class on Mondays, 08:30–10:00 now takes place in room Amphi B.',
    });

    await request(app)
      .patch(`${SLOTS}/algo-cm`)
      .set(admin.auth)
      .send({ mode: 'online', meetUrl: MEET });
    expect(await latest()).toMatchObject({
      title: 'Algorithmes & Complexité: room changed Amphi B → Online (Mondays, 08:30)',
      body: 'Your class on Mondays, 08:30–10:00 now takes place online.',
    });

    await request(app).patch(`${SLOTS}/algo-cm`).set(admin.auth).send({ weekday: 6 });
    expect(await latest()).toMatchObject({
      title: 'Algorithmes & Complexité: class moved Mondays, 08:30 → Saturdays, 08:30',
    });

    await request(app).delete(`${SLOTS}/algo-cm`).set(admin.auth).expect(204);
    expect(await latest()).toMatchObject({
      title: 'Algorithmes & Complexité: class removed (Saturdays, 08:30)',
      body: 'Your class on Saturdays, 08:30–10:00 is no longer in your timetable.',
    });
    expect(await AuditLogModel.countDocuments({ action: 'timetable.slot.delete' })).toBe(1);
  });

  test('saving a class without any change notifies nobody', async () => {
    const { admin, student } = await campus();
    await request(app).patch(`${SLOTS}/algo-cm`).set(admin.auth).send({ room: 'Amphi A' }).expect(200);
    expect(await notificationsOf(student)).toEqual([]);
    expect(await AuditLogModel.findOne().lean()).toMatchObject({ metadata: { notified: 0 } });
  });
});

describe('class reminders', () => {
  test('a class added by an admin is reminded, online ones say so', async () => {
    const admin = await seededAdmin();
    const student = await createStudent();
    await PushDeviceModel.create({ userId: student.user._id, token: 'student-phone', platform: 'android' });
    await create(admin, saturdayClass({ mode: 'online', room: '', meetUrl: MEET }));
    await push.settle();
    push.reset();

    // Saturday 14 November 2026, 08:50 on campus.
    const run = await sendClassReminders(new Date('2026-11-14T08:50:00+01:00'));

    expect(run.reminded).toEqual([
      { sessionId: expect.stringMatching(/^cloud-computing-[0-9a-f]{4}-2026-11-14$/), course: 'Cloud Computing', start: '09:00' },
    ]);
    expect(push.messages.map((m) => m.notification)).toEqual([
      { title: 'Cloud Computing', body: 'Lecture in 10 min · 09:00–11:00 · Online' },
    ]);
  });
});
