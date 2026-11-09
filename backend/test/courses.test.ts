import request from 'supertest';

import { createApp } from '../src/app';
import { clock } from '../src/modules/courses/campus-time';
import { DEMO_COURSES } from '../src/modules/courses/courses.data';
import {
  CourseAttendanceModel,
  CourseModel,
  CourseResourceModel,
} from '../src/modules/courses/courses.model';
import { seedCourses } from '../src/modules/courses/courses.seed';
import type { CourseJson, CourseResourceJson } from '../src/modules/courses/courses.service';
import { clearTestDb, closeTestDb, connectTestDb, createStudent } from './helpers';

const app = createApp();

/** Thursday 5 November 2026, 09:00 on campus (UTC+1). */
const THURSDAY_9AM = new Date('2026-11-05T08:00:00Z');

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(async () => {
  await clearTestDb();
  jest.spyOn(clock, 'now').mockReturnValue(THURSDAY_9AM);
});
afterEach(() => jest.restoreAllMocks());

type Auth = { Authorization: string };

/** The demo student, with the demo catalog and attendance seeded. */
async function demoStudent() {
  const student = await createStudent({ displayName: 'Dony Mansour' });
  await seedCourses(student.user._id);
  return student;
}

async function getCourses(auth: Auth): Promise<CourseJson[]> {
  const res = await request(app).get('/api/courses').set(auth).expect(200);
  return res.body as CourseJson[];
}

const byId = (courses: CourseJson[], id: string) => courses.find((c) => c.id === id)!;

function resource<T extends CourseResourceJson['type']>(
  course: CourseJson,
  type: T,
): Extract<CourseResourceJson, { type: T }> {
  return course.resources.find((r) => r.type === type) as Extract<CourseResourceJson, { type: T }>;
}

const submit = (auth: Auth, assignmentId: string, repoUrl: unknown) =>
  request(app)
    .post(`/api/courses/assignments/${assignmentId}/submission`)
    .set(auth)
    .send({ repoUrl });

describe('auth', () => {
  test.each([
    ['get', '/api/courses'],
    ['put', '/api/courses/genie-logiciel/attendance'],
    ['post', '/api/courses/resources/gl-lesson-7/download'],
    ['post', '/api/courses/assignments/gl-lab-3/submission'],
  ] as const)('%s %s needs a token', async (method, path) => {
    const res = await request(app)[method](path).send({}).expect(401);
    expect(res.body).toEqual({ message: expect.any(String) });
  });

  test.each(['admin', 'alumni'] as const)('%s accounts have no courses (403)', async (role) => {
    const { auth } = await createStudent({ role });
    await seedCourses((await createStudent()).user._id);

    for (const [method, path] of [
      ['get', '/api/courses'],
      ['put', '/api/courses/genie-logiciel/attendance'],
      ['post', '/api/courses/resources/gl-lesson-7/download'],
      ['post', '/api/courses/assignments/gl-lab-3/submission'],
    ] as const) {
      const res = await request(app)[method](path).set(auth).send({ present: true }).expect(403);
      expect(res.body).toEqual({ message: 'Only students and teachers have courses.' });
    }
  });

  test('teachers have the courses', async () => {
    const teacher = await createStudent({ role: 'teacher' });
    await seedCourses(teacher.user._id);
    expect(await getCourses(teacher.auth)).toHaveLength(DEMO_COURSES.length);
  });
});

describe('GET /api/courses', () => {
  test('returns the ported demo courses, in order, with the mock ids', async () => {
    const { auth } = await demoStudent();
    const courses = await getCourses(auth);

    expect(courses.map((c) => c.id)).toEqual(['genie-logiciel', 'algo', 'bases-de-donnees']);
    const gl = courses[0]!;
    expect(gl).toMatchObject({
      code: 'GLA-401',
      location: 'Block 2B',
      title: 'Génie Logiciel & Architecture',
      term: 'Winter Semester',
      track: 'Advanced Software Systems Track',
      professor: {
        title: 'Prof.',
        name: 'Ben Ali',
        office: 'Office Bloc B-114',
        email: 'benali@campus.edu',
        isOnline: true,
      },
      lecturesHeld: 7,
      lectureCount: 14,
      isPresent: true,
    });
    expect(gl.modules).toHaveLength(14);
    expect(gl.modules[0]).toEqual({
      number: 1,
      title: 'Software Engineering Foundations',
      hours: 3,
      isCompleted: true,
    });
    expect(gl.modules.filter((m) => m.isCompleted)).toHaveLength(10);
    expect(gl.community.onlineCount).toBe(24);
    expect(gl.community.onlineClassmates).toHaveLength(10);
    expect(gl.resources.map((r) => [r.id, r.type])).toEqual([
      ['gl-lesson-7', 'document'],
      ['gl-lesson-8', 'video'],
      ['gl-lab-3', 'assignment'],
    ]);
    expect(resource(gl, 'video')).toEqual({
      type: 'video',
      id: 'gl-lesson-8',
      title: 'Lesson 8: Clean Code & SOLID',
      durationSeconds: 2700,
      quality: '1080p',
    });

    expect(byId(courses, 'algo').isPresent).toBe(true);
    const bdd = byId(courses, 'bases-de-donnees');
    expect(bdd.isPresent).toBe(false);
    expect(bdd.nextQuiz).toBeNull();
    expect(resource(bdd, 'assignment').isMandatory).toBe(false);
  });

  test('dates are relative to today on campus (UTC+1)', async () => {
    const { auth } = await demoStudent();
    const [gl, algo, bdd] = await getCourses(auth);

    // In 4 days at 10:15, tomorrow at 08:30.
    expect(gl!.nextQuiz).toEqual({
      topic: 'Arch Microservices',
      date: '2026-11-09T09:15:00.000Z',
    });
    expect(algo!.nextQuiz!.date).toBe('2026-11-06T07:30:00.000Z');
    // Next Friday at 23:59.
    expect(resource(gl!, 'assignment')).toEqual({
      type: 'assignment',
      id: 'gl-lab-3',
      title: 'Lab 3: Docker Orchestration',
      description: 'Kubernetes cluster config & compose manifest',
      dueAt: '2026-11-06T22:59:00.000Z',
      points: 20,
      isMandatory: true,
      submittedRepoUrl: null,
    });
    // Updated 24 days ago (at midnight).
    expect(resource(gl!, 'document')).toEqual({
      type: 'document',
      id: 'gl-lesson-7',
      title: 'Lesson 7: Microservices & REST APIs',
      format: 'PDF',
      sizeBytes: 4404019,
      updatedAt: '2026-10-11T23:00:00.000Z',
    });
    expect(resource(bdd!, 'assignment').dueAt).toBe('2026-11-07T11:00:00.000Z');
  });

  test('the lab is due next Friday, never today, using the campus date', async () => {
    const { auth } = await demoStudent();
    const dueAt = async () => resource((await getCourses(auth))[0]!, 'assignment').dueAt;

    jest.spyOn(clock, 'now').mockReturnValue(new Date('2026-11-06T08:00:00Z')); // Friday
    expect(await dueAt()).toBe('2026-11-13T22:59:00.000Z');

    // 23:30 UTC on Thursday is already Friday 00:30 on campus.
    jest.spyOn(clock, 'now').mockReturnValue(new Date('2026-11-05T23:30:00Z'));
    expect(await dueAt()).toBe('2026-11-13T22:59:00.000Z');
  });

  test('a brand-new student sees the catalog with empty personal state', async () => {
    await demoStudent();
    const { auth } = await createStudent();
    const courses = await getCourses(auth);

    expect(courses.map((c) => c.id)).toEqual(['genie-logiciel', 'algo', 'bases-de-donnees']);
    expect(courses.map((c) => c.isPresent)).toEqual([false, false, false]);
    for (const c of courses) {
      for (const r of c.resources) {
        if (r.type === 'assignment') expect(r.submittedRepoUrl).toBeNull();
      }
    }
  });

  test('is an empty list when there is no catalog', async () => {
    const { auth } = await createStudent();
    expect(await getCourses(auth)).toEqual([]);
  });
});

describe('PUT /api/courses/:courseId/attendance', () => {
  test('logs and undoes attendance for this student only', async () => {
    const demo = await demoStudent();
    const other = await createStudent();

    await request(app)
      .put('/api/courses/bases-de-donnees/attendance')
      .set(other.auth)
      .send({ present: true })
      .expect(204);
    await request(app)
      .put('/api/courses/genie-logiciel/attendance')
      .set(demo.auth)
      .send({ present: false })
      .expect(204);

    expect((await getCourses(other.auth)).map((c) => c.isPresent)).toEqual([false, false, true]);
    expect((await getCourses(demo.auth)).map((c) => c.isPresent)).toEqual([false, true, false]);
  });

  test('unknown course is a 404', async () => {
    const { auth } = await demoStudent();
    const res = await request(app)
      .put('/api/courses/nope/attendance')
      .set(auth)
      .send({ present: true })
      .expect(404);
    expect(res.body).toEqual({ message: 'Course not found.' });
  });

  test.each([{}, { present: 'yes' }, { present: null }])('%j is a 422', async (body) => {
    const { auth } = await demoStudent();
    const res = await request(app)
      .put('/api/courses/genie-logiciel/attendance')
      .set(auth)
      .send(body)
      .expect(422);
    expect(res.body).toEqual({ message: 'Say whether you were present (true or false)' });
  });
});

describe('POST /api/courses/resources/:resourceId/download', () => {
  test('gives a link to a document', async () => {
    const { auth } = await demoStudent();
    const res = await request(app)
      .post('/api/courses/resources/gl-lesson-7/download')
      .set(auth)
      .expect(200);
    expect(res.body).toEqual({
      url: 'https://files.campuspulse.test/courses/genie-logiciel/gl-lesson-7.pdf',
    });
  });

  test('videos are streamed, not downloaded: 409', async () => {
    const { auth } = await demoStudent();
    const res = await request(app)
      .post('/api/courses/resources/gl-lesson-8/download')
      .set(auth)
      .expect(409);
    expect(res.body).toEqual({ message: 'Only documents can be downloaded.' });
  });

  test('unknown resource is a 404', async () => {
    const { auth } = await demoStudent();
    const res = await request(app)
      .post('/api/courses/resources/nope/download')
      .set(auth)
      .expect(404);
    expect(res.body).toEqual({ message: 'File not found.' });
  });
});

describe('POST /api/courses/assignments/:assignmentId/submission', () => {
  test('hands in a lab for this student only; submitting again replaces the link', async () => {
    const demo = await demoStudent();
    const other = await createStudent();

    const res = await submit(demo.auth, 'gl-lab-3', '  https://github.com/dony/docker-lab ')
      .expect(201);
    expect(res.body).toEqual({
      assignmentId: 'gl-lab-3',
      repoUrl: 'https://github.com/dony/docker-lab',
      submittedAt: expect.any(String),
    });
    const lab = async (auth: Auth) => resource((await getCourses(auth))[0]!, 'assignment');
    expect((await lab(demo.auth)).submittedRepoUrl).toBe('https://github.com/dony/docker-lab');
    expect((await lab(other.auth)).submittedRepoUrl).toBeNull();

    await submit(demo.auth, 'gl-lab-3', 'https://gitlab.com/dony/docker-lab-v2').expect(201);
    expect((await lab(demo.auth)).submittedRepoUrl).toBe('https://gitlab.com/dony/docker-lab-v2');
  });

  test.each([
    ['not https', 'http://github.com/me/lab'],
    ['no scheme', 'github.com/me/lab'],
    ['no repository name', 'https://github.com/me'],
    ['no domain', 'https://localhost/me/lab'],
    ['spaces', 'https://github.com/me/my lab'],
    ['empty', '   '],
    ['not a string', 42],
  ])('%s is a 422 with a readable message', async (_name, repoUrl) => {
    const { auth } = await demoStudent();
    const res = await submit(auth, 'gl-lab-3', repoUrl).expect(422);
    expect(res.body).toEqual({ message: 'Enter a valid https:// repository link.' });
  });

  test('a missing link is a 422', async () => {
    const { auth } = await demoStudent();
    const res = await request(app)
      .post('/api/courses/assignments/gl-lab-3/submission')
      .set(auth)
      .send({})
      .expect(422);
    expect(res.body).toEqual({ message: 'Enter a valid https:// repository link.' });
  });

  test.each(['nope', 'gl-lesson-7'])('%s is not an assignment: 404', async (id) => {
    const { auth } = await demoStudent();
    const res = await submit(auth, id, 'https://github.com/me/lab').expect(404);
    expect(res.body).toEqual({ message: 'Assignment not found.' });
  });
});

describe('seedCourses', () => {
  test('is idempotent and resets the demo attendance', async () => {
    const { user, auth } = await demoStudent();
    await request(app)
      .put('/api/courses/genie-logiciel/attendance')
      .set(auth)
      .send({ present: false })
      .expect(204);
    await submit(auth, 'algo-lab-4', 'https://github.com/dony/graphs').expect(201);

    await seedCourses(user._id);

    expect(await CourseModel.countDocuments()).toBe(DEMO_COURSES.length);
    expect(await CourseResourceModel.countDocuments()).toBe(8);
    expect(await CourseAttendanceModel.countDocuments()).toBe(3);
    const courses = await getCourses(auth);
    expect(courses.map((c) => c.isPresent)).toEqual([true, true, false]);
    expect(resource(courses[1]!, 'assignment').submittedRepoUrl).toBe(
      'https://github.com/dony/graphs',
    );
  });

  test('resource ids are unique across courses', () => {
    const ids = DEMO_COURSES.flatMap((c) => c.resources.map((r) => r._id));
    expect(new Set(ids).size).toBe(ids.length);
  });
});
