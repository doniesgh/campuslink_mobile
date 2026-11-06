import request from 'supertest';

import { createApp } from '../src/app';
import {
  courseAverage,
  evaluateSemester,
  roundGrade,
  topPercent,
  weightedAverage,
} from '../src/modules/grades/grading';
import { seedGrades, DEMO_SEMESTERS } from '../src/modules/grades/grades.seed';
import { getTranscript, type TranscriptJson } from '../src/modules/grades/grades.service';
import { TranscriptModel, type StoredSemester } from '../src/modules/grades/transcript.model';
import { clock, tunisTime } from '../src/modules/profile/academic-calendar';
import { StudentProfileModel } from '../src/modules/profile/profile.model';
import { seedProfile } from '../src/modules/profile/profile.seed';
import { UserModel } from '../src/modules/users/user.model';
import { clearTestDb, closeTestDb, connectTestDb, createStudent } from './helpers';

const app = createApp();
const realNow = clock.now;

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);
afterEach(() => {
  clock.now = realNow;
});

/** 5 November 2026, 10:00 in Tunis: a 4th-year student is in S7. */
const NOV_2026 = tunisTime(2026, 11, 5, 10);

/** The demo student, as `npm run seed` creates it. */
async function seededDemoStudent() {
  const student = await createStudent({ studentId: '211JMT0428', displayName: 'Dony Mansour' });
  await seedGrades(student.user._id);
  await seedProfile(student.user._id);
  return student;
}

const labels = (t: TranscriptJson) => t.semesters.map((s) => `${s.academicYear} · Sem ${s.number}`);

describe('GET /api/grades/transcript', () => {
  test('needs a valid token', async () => {
    const none = await request(app).get('/api/grades/transcript').expect(401);
    expect(none.body).toEqual({ message: 'Invalid credentials or expired session.' });
    await request(app)
      .get('/api/grades/transcript')
      .set({ Authorization: 'Bearer not-a-token' })
      .expect(401);
  });

  test('answers 401 for a deleted account', async () => {
    const { user, auth } = await createStudent();
    await UserModel.deleteOne({ _id: user._id });
    await request(app).get('/api/grades/transcript').set(auth).expect(401);
  });

  test('a student with no grades gets no semesters', async () => {
    const { auth } = await createStudent({ studentId: '221JMT0001' });
    const res = await request(app).get('/api/grades/transcript').set(auth).expect(200);
    expect(res.body).toEqual({ studentId: '221JMT0001', semesters: [] });
  });

  test('studentId is null when the account has no ENT ID yet', async () => {
    const { auth } = await createStudent();
    const res = await request(app).get('/api/grades/transcript').set(auth).expect(200);
    expect(res.body).toEqual({ studentId: null, semesters: [] });
  });

  test('the seeded demo student gets the mock transcript, relative to the request date', async () => {
    clock.now = () => NOV_2026;
    const { auth } = await seededDemoStudent();

    const res = await request(app).get('/api/grades/transcript').set(auth).expect(200);
    const body = res.body as TranscriptJson;

    expect(body.studentId).toBe('211JMT0428');
    expect(labels(body)).toEqual([
      '2025–2026 · Sem 6',
      '2025–2026 · Sem 5',
      '2024–2025 · Sem 4',
    ]);
    expect(body.semesters.map((s) => s.id)).toEqual([
      '2025-2026-s6',
      '2025-2026-s5',
      '2024-2025-s4',
    ]);
    expect(body.semesters.map((s) => s.updatedAt)).toEqual([
      '2026-11-05T07:00:00.000Z', // 2 hours ago
      '2026-02-07T13:30:00.000Z', // fall S5: 7 February, 14:30 in Tunis
      '2025-07-03T09:00:00.000Z', // spring S4: 3 July, 10:00 in Tunis
    ]);
    expect(body.semesters[0]).toEqual({
      id: '2025-2026-s6',
      academicYear: '2025–2026',
      number: 6,
      updatedAt: '2026-11-05T07:00:00.000Z',
      rank: 7,
      cohortSize: 142,
      signedBy: 'Dean Marc Lefèvre',
      documentSizeMb: 1.4,
      courses: [
        {
          code: 'CS-401',
          title: 'Génie Logiciel & Microservices',
          coefficient: 3,
          credits: 10,
          continuous: 17.5,
          exam: 16,
        },
        {
          code: 'DB-408',
          title: 'Conception & BDD NoSQL',
          coefficient: 2.5,
          credits: 8,
          continuous: 18,
          exam: 15.5,
        },
        {
          code: 'SEC-402',
          title: 'Réseaux & Sécurité Informatique',
          coefficient: 2,
          credits: 7,
          continuous: 14.5,
          exam: 15,
        },
        {
          code: 'HUM-304',
          title: 'Anglais Pro & Soft Skills',
          coefficient: 1.5,
          credits: 5,
          continuous: 19,
          exam: null,
        },
      ],
    });
    expect(body.semesters.map((s) => [s.rank, s.cohortSize, s.documentSizeMb])).toEqual([
      [7, 142, 1.4],
      [11, 142, 1.3],
      [48, 140, 1.2],
    ]);
    expect(body.semesters[2].courses.map((c) => c.code)).toEqual([
      'CS-301',
      'MATH-303',
      'SYS-304',
      'HUM-204',
    ]);
  });

  test('the seed is idempotent', async () => {
    const { user } = await seededDemoStudent();
    await seedGrades(user._id);
    await seedProfile(user._id);
    expect(await TranscriptModel.countDocuments({ userId: user._id })).toBe(1);
    expect(await StudentProfileModel.countDocuments({ userId: user._id })).toBe(1);
  });

  test("one student never sees another's grades", async () => {
    const demo = await seededDemoStudent();
    const other = await createStudent({ studentId: '221JMT0002' });
    await StudentProfileModel.create({ userId: other.user._id, yearOfStudy: 2 });
    await TranscriptModel.create({
      userId: other.user._id,
      semesters: [
        {
          semestersAgo: 1,
          courses: [
            { code: 'MATH-101', title: 'Analyse 1', coefficient: 2, credits: 6, exam: 11 },
          ],
        },
      ],
    });
    clock.now = () => NOV_2026;

    const mine = await request(app).get('/api/grades/transcript').set(other.auth).expect(200);
    expect(mine.body).toEqual({
      studentId: '221JMT0002',
      semesters: [
        {
          id: '2025-2026-s2',
          academicYear: '2025–2026',
          number: 2,
          updatedAt: '2026-07-03T09:00:00.000Z',
          rank: null,
          cohortSize: null,
          signedBy: null,
          documentSizeMb: null,
          courses: [
            {
              code: 'MATH-101',
              title: 'Analyse 1',
              coefficient: 2,
              credits: 6,
              continuous: null,
              exam: 11,
            },
          ],
        },
      ],
    });

    const theirs = await request(app).get('/api/grades/transcript').set(demo.auth).expect(200);
    expect((theirs.body as TranscriptJson).semesters).toHaveLength(3);
    expect(JSON.stringify(theirs.body)).not.toContain('MATH-101');
  });
});

describe('semesters follow the academic calendar', () => {
  let userId: string;

  beforeEach(async () => {
    userId = (await seededDemoStudent()).user.id;
  });

  test('March 2027 (spring, current S8): Sem 7, 6, 5 with the same marks', async () => {
    const now = tunisTime(2027, 3, 10, 9);
    const t = await getTranscript(userId, now);
    expect(labels(t)).toEqual(['2026–2027 · Sem 7', '2025–2026 · Sem 6', '2025–2026 · Sem 5']);
    expect(t.semesters.map((s) => s.id)).toEqual(['2026-2027-s7', '2025-2026-s6', '2025-2026-s5']);
    expect(t.semesters.map((s) => s.updatedAt)).toEqual([
      new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString(),
      '2026-07-03T09:00:00.000Z',
      '2026-02-07T13:30:00.000Z',
    ]);
    expect(t.semesters[0].courses[0].code).toBe('CS-401');
  });

  test('January 2027 is still the fall (current S7): Sem 6, 5, 4', async () => {
    const t = await getTranscript(userId, tunisTime(2027, 1, 15, 9));
    expect(labels(t)).toEqual(['2025–2026 · Sem 6', '2025–2026 · Sem 5', '2024–2025 · Sem 4']);
  });

  test('September 2027 starts a new academic year (current S7 again)', async () => {
    const t = await getTranscript(userId, tunisTime(2027, 9, 20));
    expect(labels(t)[0]).toBe('2026–2027 · Sem 6');
    expect(labels(t)[2]).toBe('2025–2026 · Sem 4');
  });

  test('dates are read in Tunisia: 31 Aug 23:30 UTC is already 1 September', async () => {
    const t = await getTranscript(userId, new Date('2026-08-31T23:30:00Z'));
    expect(labels(t)[0]).toBe('2025–2026 · Sem 6');
    const before = await getTranscript(userId, new Date('2026-08-31T22:30:00Z'));
    expect(labels(before)[0]).toBe('2025–2026 · Sem 7');
  });

  test('never shows a semester before S1', async () => {
    await StudentProfileModel.updateOne({ userId }, { $set: { yearOfStudy: 1 } });
    expect((await getTranscript(userId, NOV_2026)).semesters).toEqual([]); // current S1
    const spring = await getTranscript(userId, tunisTime(2027, 3, 1));
    expect(labels(spring)).toEqual(['2026–2027 · Sem 1']); // current S2
  });
});

describe('grading rules (same as the app)', () => {
  test('roundGrade: 2 decimals, half away from zero', () => {
    expect(roundGrade(16.572222)).toBe(16.57);
    expect(roundGrade(12.345)).toBe(12.35);
    expect(roundGrade(9.995)).toBe(10);
    expect(roundGrade(-0.345)).toBe(-0.35);
  });

  test('courseAverage: 40/60, or the only mark', () => {
    expect(courseAverage(17.5, 16)).toBe(16.6);
    expect(courseAverage(13.33, 11.17)).toBe(12.03);
    expect(courseAverage(19, null)).toBe(19);
    expect(courseAverage(null, 12.25)).toBe(12.25);
    expect(courseAverage(null, null)).toBeNull();
  });

  test('weightedAverage and topPercent', () => {
    expect(weightedAverage([[16.6, 3], [16.5, 2.5], [14.8, 2], [19, 1.5]])).toBe(16.57);
    expect(weightedAverage([[14, 0]])).toBeNull();
    expect(topPercent(7, 142)).toBe(5);
    expect(topPercent(48, 140)).toBe(35);
    expect(topPercent(null, 142)).toBeNull();
    expect(topPercent(150, 142)).toBeNull();
  });

  test('the demo semesters give the same results as in the app', () => {
    const [latest, middle, oldest] = DEMO_SEMESTERS.map((s: StoredSemester) =>
      evaluateSemester(s.courses),
    );
    expect(latest).toEqual({ average: 16.57, creditsEarned: 30, isHonorRoll: true });
    expect(middle).toEqual({ average: 16.22, creditsEarned: 30, isHonorRoll: true });
    // MATH-303 (9.10) is compensated: credits earned, but no honor roll.
    expect(oldest).toEqual({ average: 12.29, creditsEarned: 30, isHonorRoll: false });
  });

  test('failed and pending courses earn nothing', () => {
    const failed = evaluateSemester([
      { coefficient: 1, credits: 10, continuous: null, exam: 12 },
      { coefficient: 2, credits: 20, continuous: null, exam: 8 },
    ]);
    expect(failed).toEqual({ average: 9.33, creditsEarned: 10, isHonorRoll: false });

    const pending = evaluateSemester([
      { coefficient: 1, credits: 10, continuous: 15, exam: null },
      { coefficient: 1, credits: 20, continuous: null, exam: null },
    ]);
    expect(pending).toEqual({ average: 15, creditsEarned: 10, isHonorRoll: false });
  });
});
