import request from 'supertest';
import { Types } from 'mongoose';

import { createApp } from '../src/app';
import { JobApplicationModel, JobModel } from '../src/modules/jobs/jobs.model';
import { seedJobs } from '../src/modules/jobs/jobs.seed';
import { clearTestDb, closeTestDb, connectTestDb, createStudent } from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

const seed = () => seedJobs(new Types.ObjectId());
const apply = (auth: { Authorization: string }, jobId = 'instadeep-ml') =>
  request(app).post(`/api/jobs/${jobId}/applications`).set(auth);

describe('every jobs route needs a token', () => {
  test.each([
    ['get', '/api/jobs'],
    ['get', '/api/jobs/instadeep-ml'],
    ['post', '/api/jobs/instadeep-ml/applications'],
  ] as const)('%s %s answers 401', async (method, path) => {
    const res = await request(app)[method](path).expect(401);
    expect(res.body).toEqual({ message: 'Invalid credentials or expired session.' });
  });
});

describe('GET /api/jobs', () => {
  test('returns the seeded demo offers, best match first', async () => {
    await seed();
    const { auth } = await createStudent();

    const res = await request(app).get('/api/jobs').set(auth).expect(200);
    const jobs = res.body as { id: string; featuredLabel: string | null }[];

    expect(jobs.map((j) => j.id)).toEqual(['instadeep-ml', 'nimbus-backend', 'carthage-robotics']);
    expect(jobs.map((j) => j.featuredLabel)).toEqual(['FEATURED RESEARCH OPENING', null, null]);
    expect(jobs[2]).toEqual({
      id: 'carthage-robotics',
      featuredLabel: null,
      title: 'Computer Vision Intern',
      company: 'Carthage Robotics',
      location: 'Ghazela Technopark',
      tags: ['PFE 2025', 'Hybrid (2 days on-site)'],
      stipendTnd: 1000,
      durationMonths: 5,
      period: 'Mar – Jul 2025',
      labGroup: 'Vision',
      labGroupNote: 'Perception Lab',
      workspaceTitle: 'Carthage Robotics Lab',
      workspaceBadges: ['6 Current Interns'],
      mission: 'Prototype perception pipelines for autonomous warehouse robots.',
      missionItems: [
        {
          title: 'Perception Prototyping',
          description: 'Train and evaluate detection models on real robot footage.',
        },
      ],
      matchPercent: 76,
      criteria: ['Experience with OpenCV or PyTorch.', 'Interest in robotics.'],
      skills: ['Python', 'OpenCV', 'PyTorch'],
    });
  });

  test('is empty before the seed', async () => {
    const { auth } = await createStudent();
    await request(app).get('/api/jobs').set(auth).expect(200, []);
  });
});

describe('GET /api/jobs/:id', () => {
  test('returns one offer', async () => {
    await seed();
    const { auth } = await createStudent();

    const res = await request(app).get('/api/jobs/instadeep-ml').set(auth).expect(200);

    expect(res.body).toMatchObject({
      id: 'instadeep-ml',
      featuredLabel: 'FEATURED RESEARCH OPENING',
      title: 'Junior AI & ML Research Intern',
      company: 'InstaDeep Ltd',
      tags: ['PFE 2025', 'Hybrid (3 days on-site)', 'Coeff PFE 20.0'],
      stipendTnd: 1200,
      durationMonths: 6,
      period: 'Feb – Jul 2025',
      matchPercent: 94,
      skills: ['PyTorch', 'JAX', 'Reinforcement Learning', 'Git/Docker', 'CUDA'],
    });
    expect((res.body as { missionItems: unknown[] }).missionItems).toHaveLength(3);
  });

  test('answers 404 for an unknown offer', async () => {
    await seed();
    const { auth } = await createStudent();
    const res = await request(app).get('/api/jobs/unknown-offer').set(auth).expect(404);
    expect(res.body).toEqual({ message: 'Job not found.' });
  });
});

describe('POST /api/jobs/:id/applications', () => {
  test('records the application and answers 201', async () => {
    await seed();
    const { user, auth } = await createStudent();

    const res = await apply(auth).expect(201);

    expect(res.body).toEqual({ jobId: 'instadeep-ml', appliedAt: expect.any(String) });
    expect(new Date((res.body as { appliedAt: string }).appliedAt).toISOString()).toBe(
      (res.body as { appliedAt: string }).appliedAt,
    );
    expect(await JobApplicationModel.countDocuments({ userId: user._id })).toBe(1);
  });

  test('answers 409 when the student applies twice', async () => {
    await seed();
    const { auth } = await createStudent();
    await apply(auth).expect(201);

    const res = await apply(auth).expect(409);
    expect(res.body).toEqual({ message: 'You already applied to this offer.' });
  });

  test('keeps each student\'s applications separate', async () => {
    await seed();
    const first = await createStudent();
    const second = await createStudent();
    await apply(first.auth).expect(201);

    await apply(second.auth).expect(201);
    await apply(first.auth, 'nimbus-backend').expect(201);
    expect(await JobApplicationModel.countDocuments()).toBe(3);
  });

  test('accepts only one of two identical applications sent at the same time', async () => {
    await seed();
    const { auth } = await createStudent();

    const results = await Promise.all([apply(auth), apply(auth)]);

    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    expect(await JobApplicationModel.countDocuments()).toBe(1);
  });

  test('answers 404 for an unknown offer', async () => {
    await seed();
    const { auth } = await createStudent();
    const res = await apply(auth, 'unknown-offer').expect(404);
    expect(res.body).toEqual({ message: 'Job not found.' });
  });
});

describe('seedJobs', () => {
  test('is idempotent and keeps the students\' applications', async () => {
    await seed();
    const { auth } = await createStudent();
    await apply(auth).expect(201);

    await seed();

    expect(await JobModel.countDocuments()).toBe(3);
    await apply(auth).expect(409);
  });

  test('resets only the demo student\'s applications', async () => {
    const demo = await createStudent();
    const other = await createStudent();
    await seedJobs(demo.user._id);
    await apply(demo.auth).expect(201);
    await apply(other.auth).expect(201);

    await seedJobs(demo.user._id);

    await apply(demo.auth).expect(201);
    await apply(other.auth).expect(409);
  });
});
