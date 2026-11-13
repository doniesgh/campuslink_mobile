import request from 'supertest';

import { createApp } from '../src/app';
import { TimetableTemplateModel } from '../src/modules/timetable/timetable.model';
import { seedTimetable } from '../src/modules/timetable/timetable.seed';
import type {
  TimetableDayJson,
  TimetableWeekJson,
} from '../src/modules/timetable/timetable.service';
import { clearTestDb, closeTestDb, connectTestDb, createStudent, validationError } from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

async function seededStudent() {
  const student = await createStudent();
  await seedTimetable(student.user._id);
  return student;
}

type Auth = { Authorization: string };

async function getWeek(auth: Auth, date: string): Promise<TimetableWeekJson> {
  const res = await request(app).get('/api/timetable/week').query({ date }).set(auth).expect(200);
  return res.body as TimetableWeekJson;
}

async function getDay(auth: Auth, date: string): Promise<TimetableDayJson> {
  const res = await request(app).get('/api/timetable/day').query({ date }).set(auth).expect(200);
  return res.body as TimetableDayJson;
}

describe('auth', () => {
  test.each(['/api/timetable/day', '/api/timetable/week'])('%s needs a token', async (path) => {
    const res = await request(app).get(path).query({ date: '2026-11-05' }).expect(401);
    expect(res.body).toEqual({ message: expect.any(String) });
  });

  test.each(['admin', 'alumni'] as const)('%s accounts have no timetable (403)', async (role) => {
    const { auth } = await createStudent({ role });
    for (const path of ['/api/timetable/day', '/api/timetable/week']) {
      const res = await request(app).get(path).query({ date: '2026-11-05' }).set(auth).expect(403);
      expect(res.body).toEqual({ message: 'Only students and teachers have a timetable.' });
    }
  });

  test('teachers have the class group timetable', async () => {
    const teacher = await createStudent({ role: 'teacher' });
    await seedTimetable(teacher.user._id);

    const week = await getWeek(teacher.auth, '2026-11-05');

    expect(week.classGroup).toBe('Tech Track 4BI');
    expect(week.days.flatMap((d) => d.sessions).length).toBeGreaterThan(0);
  });
});

describe('date validation', () => {
  test.each([
    ['missing', {}, 'Pass the date as YYYY-MM-DD'],
    ['not padded', { date: '2026-11-5' }, 'Pass the date as YYYY-MM-DD'],
    ['with a time', { date: '2026-11-05T10:00:00Z' }, 'Pass the date as YYYY-MM-DD'],
    ['repeated', { date: ['2026-11-05', '2026-11-06'] }, 'Pass the date as YYYY-MM-DD'],
    ['impossible', { date: '2026-02-30' }, 'This date does not exist'],
  ])('a %s date is a 422', async (_name, query, message) => {
    const { auth } = await createStudent();
    for (const path of ['/api/timetable/day', '/api/timetable/week']) {
      const res = await request(app).get(path).query(query).set(auth).expect(422);
      expect(res.body).toEqual(validationError(message));
    }
  });
});

describe('GET /api/timetable/week', () => {
  test('returns Monday to Sunday of the week, with the ported demo template', async () => {
    const { auth } = await seededStudent();
    const week = await getWeek(auth, '2026-11-05'); // Thursday

    expect(week.start).toBe('2026-11-02');
    expect(week.days.map((d) => d.date)).toEqual([
      '2026-11-02',
      '2026-11-03',
      '2026-11-04',
      '2026-11-05',
      '2026-11-06',
      '2026-11-07',
      '2026-11-08',
    ]);
    expect(week.semester).toBe(1);
    expect(week.classGroup).toBe('Tech Track 4BI');
    expect(week.days.map((d) => d.sessions.length)).toEqual([4, 3, 3, 4, 3, 0, 0]);

    // S1 started on a Tuesday, so its weeks turn on Tuesdays.
    expect(week.days.map((d) => d.semesterWeek)).toEqual([7, 8, 8, 8, 8, 8, 8]);
    for (const day of week.days.slice(0, 5)) {
      expect(day.sessions.slice(0, 3).map((s) => s.start)).toEqual(['08:30', '10:15', '13:30']);
      for (const s of day.sessions) expect(s.date).toBe(day.date);
    }
  });

  test('Monday is the design: a lecture, a lab, a workshop and a graded exam', async () => {
    const { auth } = await seededStudent();
    const monday = (await getWeek(auth, '2026-11-02')).days[0]!;

    expect(monday.sessions[0]).toEqual({
      id: 'algo-cm-2026-11-2',
      course: 'Algorithmes & Complexité',
      room: 'Amphi A',
      teacher: 'Prof. Trabelsi',
      date: '2026-11-02',
      start: '08:30',
      end: '10:00',
      kind: 'lecture',
      lectureNumber: 8,
      lectureCount: 14,
      coefficient: null,
      notes: null,
      mode: 'onsite',
      meetUrl: null,
    });
    expect(monday.sessions.map((s) => s.kind)).toEqual(['lecture', 'lab', 'workshop', 'exam']);
    expect(monday.sessions[3]).toMatchObject({
      id: 'cc-reseaux-2026-11-2',
      start: '16:00',
      end: '18:00',
      coefficient: 2,
      notes: 'Chapters 1–4 · Bring scientific calculator & Student ID',
    });
  });

  test('uses the mock academic calendar for the semester', async () => {
    const { auth } = await seededStudent();
    expect((await getWeek(auth, '2026-05-18')).semester).toBe(2);
    expect((await getWeek(auth, '2026-07-06')).semester).toBeNull(); // summer
    // S1 starts on Tuesday 15 September 2026: that week is in S1.
    const firstWeek = await getWeek(auth, '2026-09-14');
    expect(firstWeek.semester).toBe(1);
    expect(firstWeek.days.map((d) => d.semesterWeek)).toEqual([null, 1, 1, 1, 1, 1, 1]);
    // January still belongs to S1 (week 16 ends it).
    const january = await getWeek(auth, '2027-01-04');
    expect(january.semester).toBe(1);
    expect(january.days[0]!.semesterWeek).toBe(16);
  });

  test('a week across two months and two years', async () => {
    const { auth } = await seededStudent();
    const week = await getWeek(auth, '2027-01-01'); // Friday
    expect(week.start).toBe('2026-12-28');
    expect(week.days.at(-1)!.date).toBe('2027-01-03');
    expect(week.days[4]!.sessions[0]!.id).toBe('stats-2027-1-1');
  });
});

describe('GET /api/timetable/day', () => {
  test('agrees with the week', async () => {
    const { auth } = await seededStudent();
    const day = await getDay(auth, '2026-11-05');
    const week = await getWeek(auth, '2026-11-05');
    expect(day).toEqual(week.days[3]);
    expect(day.sessions.map((s) => [s.id, s.start, s.end])).toEqual([
      ['algo-thu-2026-11-5', '08:30', '10:00'],
      ['genie-logiciel-thu-2026-11-5', '10:15', '12:15'],
      ['bases-de-donnees-thu-2026-11-5', '13:30', '15:30'],
      ['exam-flutter-2026-11-5', '16:00', '17:30'],
    ]);
  });

  test("Friday's workshop is online, with its Google Meet link", async () => {
    const { auth } = await seededStudent();
    const friday = await getDay(auth, '2026-11-06');
    expect(friday.sessions[2]).toMatchObject({
      id: 'entrepreneuriat-2026-11-6',
      kind: 'workshop',
      // Older apps show the room as is.
      room: 'Online',
      mode: 'online',
      meetUrl: 'https://meet.google.com/xqd-fkzw-pnb',
    });
    for (const s of friday.sessions.slice(0, 2)) {
      expect(s).toMatchObject({ mode: 'onsite', meetUrl: null });
    }
  });

  test('slots saved before online classes existed are on-site', async () => {
    const { auth } = await createStudent();
    await TimetableTemplateModel.collection.insertOne({
      classGroup: 'Tech Track 4BI',
      slots: [
        {
          slotId: 'old',
          weekday: 1,
          course: 'Old class',
          room: 'B12',
          teacher: 'Dr. Old',
          start: '08:30',
          end: '10:00',
          kind: 'lecture',
        },
      ],
    });
    const monday = await getDay(auth, '2026-11-02');
    expect(monday.sessions[0]).toMatchObject({ id: 'old-2026-11-2', mode: 'onsite', meetUrl: null });
  });

  test('weekends and holidays have no classes', async () => {
    const { auth } = await seededStudent();
    expect(await getDay(auth, '2026-11-07')).toEqual({
      date: '2026-11-07',
      semesterWeek: 8,
      sessions: [],
    });
    expect((await getDay(auth, '2026-07-06')).semesterWeek).toBeNull();
  });

  test('is the same for every student of the class group, even a brand-new one', async () => {
    const demo = await seededStudent();
    const newcomer = await createStudent();
    expect(await getDay(newcomer.auth, '2026-11-02')).toEqual(
      await getDay(demo.auth, '2026-11-02'),
    );
  });

  test('without a template, days are empty but still answered', async () => {
    const { auth } = await createStudent();
    expect(await getDay(auth, '2026-11-02')).toEqual({
      date: '2026-11-02',
      semesterWeek: 7,
      sessions: [],
    });
  });
});

describe('seedTimetable', () => {
  test('is idempotent', async () => {
    const { user, auth } = await createStudent();
    await seedTimetable(user._id);
    const first = await getWeek(auth, '2026-11-05');
    await seedTimetable(user._id);
    expect(await TimetableTemplateModel.countDocuments()).toBe(1);
    expect(await getWeek(auth, '2026-11-05')).toEqual(first);
  });
});
