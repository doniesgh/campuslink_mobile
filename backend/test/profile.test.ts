import { Types } from 'mongoose';
import request from 'supertest';

import { createApp } from '../src/app';
import { seedCarpool } from '../src/modules/carpool/carpool.seed';
import { seedGrades } from '../src/modules/grades/grades.seed';
import { seedNotifications } from '../src/modules/notifications/notifications.seed';
import { TranscriptModel } from '../src/modules/grades/transcript.model';
import { clock, tunisTime } from '../src/modules/profile/academic-calendar';
import { StudentProfileModel } from '../src/modules/profile/profile.model';
import { seedProfile } from '../src/modules/profile/profile.seed';
import { getProfile, type StudentProfileJson } from '../src/modules/profile/profile.service';
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
  const student = await createStudent({
    studentId: '211JMT0428',
    displayName: 'Dony Mansour',
    email: 'dony.mansour@campus.test',
  });
  await seedGrades(student.user._id);
  await seedProfile(student.user._id);
  await seedNotifications(student.user._id); // 9 notifications, 3 unread
  return student;
}

describe('GET /api/profile', () => {
  test('needs a valid token', async () => {
    const none = await request(app).get('/api/profile').expect(401);
    expect(none.body).toEqual({ message: 'Invalid credentials or expired session.' });
    await request(app).get('/api/profile').set({ Authorization: 'Bearer nope' }).expect(401);
  });

  test('answers 401 for a deleted account', async () => {
    const { user, auth } = await createStudent();
    await UserModel.deleteOne({ _id: user._id });
    await request(app).get('/api/profile').set(auth).expect(401);
  });

  test('the seeded demo student gets the mock profile, stats from the transcript', async () => {
    clock.now = () => NOV_2026;
    const { auth } = await seededDemoStudent();

    const res = await request(app).get('/api/profile').set(auth).expect(200);
    expect(res.body).toEqual({
      studentId: '211JMT0428',
      displayName: 'Dony Mansour',
      email: 'dony.mansour@campus.test',
      program: 'Software Engineering',
      programShort: 'Software Eng.',
      className: '4BI',
      yearOfStudy: 4,
      campus: 'ESPRIT Ghazela',
      campusLocation: 'Ghazela Technopark',
      semester: 7,
      academicYearStart: 2026,
      validUntil: '2027-09-30',
      ectsCredits: 90, // 3 published semesters × 30
      gpa: 3.72,
      rankTopPercent: 5, // rank 7 of 142 in the latest semester
      promoYear: 2027,
      honours: "Dean's List", // the latest semester is on the honor roll
      isOnCampus: true,
      isVerified: true,
      nfcReady: true,
      hasEspritKey: true,
      unreadNotifications: 3, // from the notifications module
      hasCarpoolActivity: false, // no ride published or booked yet
    });
  });

  test('the counters follow the notifications and carpool modules', async () => {
    clock.now = () => NOV_2026;
    const { auth } = await seededDemoStudent();
    await seedCarpool(new Types.ObjectId());
    const profile = async () =>
      (await request(app).get('/api/profile').set(auth).expect(200)).body as StudentProfileJson;

    expect((await profile()).hasCarpoolActivity).toBe(false);
    await request(app)
      .post('/api/carpool/rides/es-4091/reservations')
      .set(auth)
      .send({ seatIds: ['s3'] })
      .expect(201);
    expect((await profile()).hasCarpoolActivity).toBe(true);

    expect((await profile()).unreadNotifications).toBe(3);
    await request(app).post('/api/notifications/read-all').set(auth).expect(204);
    expect((await profile()).unreadNotifications).toBe(0);
  });

  test('a student without a profile gets the default one', async () => {
    clock.now = () => NOV_2026;
    const { auth } = await createStudent({ displayName: 'Amira Trabelsi', email: 'amira@campus.test' });

    const res = await request(app).get('/api/profile').set(auth).expect(200);
    expect(res.body).toEqual({
      studentId: null,
      displayName: 'Amira Trabelsi',
      email: 'amira@campus.test',
      program: 'Engineering Common Core',
      programShort: 'Common Core',
      className: '1A',
      yearOfStudy: 1,
      campus: 'ESPRIT Ghazela',
      campusLocation: 'Ghazela Technopark',
      semester: 1,
      academicYearStart: 2026,
      validUntil: '2027-09-30',
      ectsCredits: 0,
      gpa: 0,
      rankTopPercent: 100,
      promoYear: 2027,
      honours: null,
      isOnCampus: false,
      isVerified: false,
      nfcReady: false,
      hasEspritKey: false,
      unreadNotifications: 0,
      hasCarpoolActivity: false,
    });
    // Reading it does not create a document.
    expect(await StudentProfileModel.countDocuments()).toBe(0);
  });

  test("one student never sees another's profile", async () => {
    clock.now = () => NOV_2026;
    const demo = await seededDemoStudent();
    const other = await createStudent({ studentId: '221JMT0002', displayName: 'Yassine Ben Ali' });
    await StudentProfileModel.create({
      userId: other.user._id,
      yearOfStudy: 2,
      program: 'Computer Science',
      programShort: 'CS',
      classGroup: 'B3',
      gpa: 2.9,
    });

    const mine = (await request(app).get('/api/profile').set(other.auth).expect(200))
      .body as StudentProfileJson;
    expect(mine).toMatchObject({
      studentId: '221JMT0002',
      displayName: 'Yassine Ben Ali',
      program: 'Computer Science',
      className: '2B3',
      semester: 3,
      ectsCredits: 0,
      gpa: 2.9,
      honours: null,
      isVerified: false, // not set: falls back to the default
    });

    const theirs = (await request(app).get('/api/profile').set(demo.auth).expect(200))
      .body as StudentProfileJson;
    expect(theirs).toMatchObject({ studentId: '211JMT0428', program: 'Software Engineering' });
  });

  test('agrees with the transcript on the current semester', async () => {
    const { auth } = await seededDemoStudent();
    const profile = (await request(app).get('/api/profile').set(auth).expect(200))
      .body as StudentProfileJson;
    const transcript = (await request(app).get('/api/grades/transcript').set(auth).expect(200))
      .body as { semesters: { number: number }[] };
    expect(transcript.semesters[0].number).toBe(profile.semester - 1);
  });
});

describe('profile stats and the calendar', () => {
  test('year, semester, card validity and promo follow the date', async () => {
    const { user } = await seededDemoStudent();

    const spring = await getProfile(user.id, tunisTime(2027, 3, 10, 9));
    expect(spring).toMatchObject({
      semester: 8,
      academicYearStart: 2026,
      validUntil: '2027-09-30',
      promoYear: 2027,
    });

    const nextYear = await getProfile(user.id, tunisTime(2027, 9, 20));
    expect(nextYear).toMatchObject({
      semester: 7,
      academicYearStart: 2027,
      validUntil: '2028-09-30',
      promoYear: 2028,
    });
  });

  test('credits count compensated courses only in validated semesters; rank falls back to the latest ranked semester', async () => {
    const { user } = await createStudent();
    await StudentProfileModel.create({ userId: user._id, yearOfStudy: 2 });
    await TranscriptModel.create({
      userId: user._id,
      semesters: [
        {
          // S2, not ranked yet: 11.40 and 8.60 → 10.00, the 8.60 is compensated.
          semestersAgo: 1,
          courses: [
            { code: 'A', title: 'A', coefficient: 1, credits: 15, continuous: 12, exam: 11 },
            { code: 'B', title: 'B', coefficient: 1, credits: 15, continuous: 8, exam: 9 },
          ],
        },
        {
          // S1: 9/20 → not validated, no credits.
          semestersAgo: 2,
          rank: 30,
          cohortSize: 120,
          courses: [{ code: 'C', title: 'C', coefficient: 1, credits: 30, exam: 9 }],
        },
      ],
    });

    const p = await getProfile(user.id, NOV_2026);
    expect(p).toMatchObject({ semester: 3, ectsCredits: 30, rankTopPercent: 25, honours: null });
  });
});
