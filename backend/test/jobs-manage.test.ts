import request from 'supertest';
import { Types } from 'mongoose';

import { createApp } from '../src/app';
import { JobApplicationModel, JobModel } from '../src/modules/jobs/jobs.model';
import { seedJobs } from '../src/modules/jobs/jobs.seed';
import {
  clearTestDb,
  closeTestDb,
  connectTestDb,
  createAdmin,
  createStudent,
  validationError,
  type TestAccount,
} from './helpers';

const app = createApp();

beforeAll(connectTestDb);
afterAll(closeTestDb);
beforeEach(clearTestDb);

type Auth = { Authorization: string };
type JobBody = Record<string, unknown> & { id: string; canEdit: boolean };

const createCompany = (displayName = 'Nadia Kooli') => createStudent({ role: 'company', displayName });

const OFFER = {
  title: 'Flutter Mobile Intern',
  company: 'Medina Soft',
  location: 'Lac 1, Tunis',
  description: 'Build the Flutter app our clients use to book appointments every day.',
  period: 'Feb – Jul 2026',
  durationMonths: 6,
  stipendTnd: 800,
  skills: ['Flutter', 'Dart', ' Flutter ', ''],
  tags: ['PFE 2026'],
};

const post = (auth: Auth, body: object = OFFER) =>
  request(app).post('/api/jobs').set(auth).send(body);

/** An offer posted by [account], returned as the API sent it. */
async function postedBy(account: TestAccount, body: object = OFFER): Promise<JobBody> {
  return (await post(account.auth, body).expect(201)).body as JobBody;
}

describe('the new routes need a token', () => {
  test.each([
    ['post', '/api/jobs'],
    ['patch', '/api/jobs/instadeep-ml'],
    ['delete', '/api/jobs/instadeep-ml'],
    ['post', '/api/jobs/instadeep-ml/summary'],
  ] as const)('%s %s answers 401', async (method, path) => {
    await request(app)[method](path).expect(401);
  });
});

describe('POST /api/jobs', () => {
  test('a company posts an offer: 201, with the defaults of what the form leaves out', async () => {
    const company = await createCompany();

    const job = await postedBy(company);

    expect(job).toEqual({
      id: expect.stringMatching(/^[0-9a-f]{24}$/),
      featuredLabel: null,
      title: 'Flutter Mobile Intern',
      company: 'Medina Soft',
      location: 'Lac 1, Tunis',
      tags: ['PFE 2026'],
      stipendTnd: 800,
      durationMonths: 6,
      period: 'Feb – Jul 2026',
      labGroup: null,
      labGroupNote: null,
      workspaceTitle: null,
      workspaceBadges: [],
      mission: OFFER.description,
      description: OFFER.description,
      missionItems: [],
      matchPercent: null,
      criteria: [],
      skills: ['Flutter', 'Dart'],
      hasApplied: false,
      authorId: company.user.id,
      canEdit: true,
    });
    expect(await JobModel.countDocuments({ authorId: company.user._id })).toBe(1);
  });

  test('only the title and the description are required; the company defaults to the author', async () => {
    const company = await createCompany('Walid Sassi');

    const job = await postedBy(company, {
      title: 'Data Intern',
      description: 'Clean and model the sales data of our retail clients.',
    });

    expect(job).toMatchObject({
      company: 'Walid Sassi',
      location: '',
      period: '',
      stipendTnd: null,
      durationMonths: null,
      skills: [],
      tags: [],
    });
  });

  test('an admin can post too', async () => {
    const admin = await createAdmin();
    const job = await postedBy(admin);
    expect(job.authorId).toBe(admin.user.id);
  });

  test.each(['student', 'teacher', 'alumni'] as const)('a %s gets a 403', async (role) => {
    const { auth } = await createStudent({ role });
    const res = await post(auth).expect(403);
    expect(res.body).toEqual({ message: 'Only companies and administrators can post offers.' });
    expect(await JobModel.countDocuments()).toBe(0);
  });

  test.each([
    [{ ...OFFER, title: undefined }, 'Enter a title.'],
    [{ ...OFFER, title: '  ab ' }, 'The title needs at least 3 characters.'],
    [{ ...OFFER, title: 'x'.repeat(121) }, 'The title can have at most 120 characters.'],
    [{ ...OFFER, description: '' }, 'Enter a description.'],
    [{ ...OFFER, description: 'Too short.' }, 'The description needs at least 20 characters.'],
    [{ ...OFFER, company: 'M' }, 'The company name needs at least 2 characters.'],
    [{ ...OFFER, durationMonths: 0 }, 'The duration is a whole number of months, from 1 to 36.'],
    [{ ...OFFER, durationMonths: 2.5 }, 'The duration is a whole number of months, from 1 to 36.'],
    [{ ...OFFER, stipendTnd: -1 }, 'The stipend is a whole number of TND, from 0 to 100000.'],
    [{ ...OFFER, skills: 'Flutter' }, 'At most 15 skills, of 40 characters each.'],
    [{ ...OFFER, tags: ['a', 'b', 'c', 'd', 'e', 'f', 'g'] }, 'At most 6 tags, of 40 characters each.'],
  ])('refuses an invalid offer with a 422 (%#)', async (body, message) => {
    const company = await createCompany();
    const res = await post(company.auth, body).expect(422);
    expect(res.body).toEqual(validationError(message));
  });
});

describe('GET /api/jobs with posted offers', () => {
  test('lists the posted offers first, newest first, then the catalogue', async () => {
    await seedJobs(new Types.ObjectId());
    const company = await createCompany();
    const first = await postedBy(company, { ...OFFER, title: 'First offer' });
    const second = await postedBy(company, { ...OFFER, title: 'Second offer' });
    const { auth } = await createStudent();

    const jobs = (await request(app).get('/api/jobs').set(auth).expect(200)).body as JobBody[];

    expect(jobs.map((j) => j.id)).toEqual([
      second.id,
      first.id,
      'instadeep-ml',
      'nimbus-backend',
      'carthage-robotics',
    ]);
  });

  test('canEdit is true for the author and admins only', async () => {
    await seedJobs(new Types.ObjectId());
    const author = await createCompany();
    const other = await createCompany('Walid Sassi');
    const admin = await createAdmin();
    const student = await createStudent();
    const job = await postedBy(author);

    const canEdit = async (account: TestAccount) => {
      const list = (await request(app).get('/api/jobs').set(account.auth)).body as JobBody[];
      const detail = (await request(app).get(`/api/jobs/${job.id}`).set(account.auth)).body as JobBody;
      expect(list.find((j) => j.id === job.id)?.canEdit).toBe(detail.canEdit);
      return [detail.canEdit, list.find((j) => j.id === 'instadeep-ml')?.canEdit];
    };

    expect(await canEdit(author)).toEqual([true, false]);
    expect(await canEdit(other)).toEqual([false, false]);
    expect(await canEdit(admin)).toEqual([true, true]);
    expect(await canEdit(student)).toEqual([false, false]);
  });
});

describe('PATCH /api/jobs/:id', () => {
  const patch = (auth: Auth, id: string, body: object) =>
    request(app).patch(`/api/jobs/${id}`).set(auth).send(body);

  test('the author changes only the fields sent; null clears a number', async () => {
    const company = await createCompany();
    const job = await postedBy(company);

    const res = await patch(company.auth, job.id, {
      title: 'Senior Flutter Intern',
      description: 'A longer mission: ship features in the Flutter app every sprint.',
      stipendTnd: null,
    }).expect(200);

    expect(res.body).toMatchObject({
      id: job.id,
      title: 'Senior Flutter Intern',
      mission: 'A longer mission: ship features in the Flutter app every sprint.',
      stipendTnd: null,
      durationMonths: 6,
      company: 'Medina Soft',
      canEdit: true,
    });
    const saved = await request(app).get(`/api/jobs/${job.id}`).set(company.auth).expect(200);
    expect(saved.body).toEqual(res.body);
  });

  test("another company gets a 403 and the offer doesn't change", async () => {
    const author = await createCompany();
    const other = await createCompany('Walid Sassi');
    const job = await postedBy(author);

    const res = await patch(other.auth, job.id, { title: 'Taken over' }).expect(403);

    expect(res.body).toEqual({ message: "This offer isn't yours." });
    expect((await JobModel.findById(job.id))?.title).toBe('Flutter Mobile Intern');
  });

  test("an admin can edit anyone's offer, and the seeded ones", async () => {
    await seedJobs(new Types.ObjectId());
    const author = await createCompany();
    const admin = await createAdmin();
    const job = await postedBy(author);

    await patch(admin.auth, job.id, { location: 'Sfax' }).expect(200);
    await patch(admin.auth, 'nimbus-backend', { stipendTnd: 950 }).expect(200);

    expect((await JobModel.findById(job.id))?.location).toBe('Sfax');
    const nimbus = await JobModel.findById('nimbus-backend');
    expect(nimbus?.stipendTnd).toBe(950);
    // The rich fields stay.
    expect(nimbus?.matchPercent).toBe(81);
  });

  test('a company cannot edit the seeded catalogue', async () => {
    await seedJobs(new Types.ObjectId());
    const company = await createCompany();
    await patch(company.auth, 'nimbus-backend', { title: 'Mine now' }).expect(403);
  });

  test('a student gets a 403 before anything else', async () => {
    const author = await createCompany();
    const student = await createStudent();
    const job = await postedBy(author);
    const res = await patch(student.auth, job.id, { title: 'Hello' }).expect(403);
    expect(res.body).toEqual({ message: 'Only companies and administrators can post offers.' });
  });

  test('answers 422 for an empty or invalid body, 404 for an unknown offer', async () => {
    const company = await createCompany();
    const job = await postedBy(company);

    expect((await patch(company.auth, job.id, {}).expect(422)).body).toEqual(
      validationError('Nothing to update.'),
    );
    expect((await patch(company.auth, job.id, { title: 'ab' }).expect(422)).body).toEqual(
      validationError('The title needs at least 3 characters.'),
    );
    expect((await patch(company.auth, 'unknown-offer', { title: 'Hello' }).expect(404)).body).toEqual(
      { message: 'Job not found.' },
    );
  });
});

describe('DELETE /api/jobs/:id', () => {
  const remove = (auth: Auth, id: string) => request(app).delete(`/api/jobs/${id}`).set(auth);

  test('the author deletes the offer and its applications: 204, then 404', async () => {
    const company = await createCompany();
    const student = await createStudent();
    const job = await postedBy(company);
    await request(app).post(`/api/jobs/${job.id}/applications`).set(student.auth).expect(201);

    await remove(company.auth, job.id).expect(204);

    await request(app).get(`/api/jobs/${job.id}`).set(student.auth).expect(404);
    expect(await JobApplicationModel.countDocuments({ jobId: job.id })).toBe(0);
  });

  test('another company gets a 403, an admin may delete', async () => {
    const author = await createCompany();
    const other = await createCompany('Walid Sassi');
    const admin = await createAdmin();
    const job = await postedBy(author);

    expect((await remove(other.auth, job.id).expect(403)).body).toEqual({
      message: "This offer isn't yours.",
    });
    await remove(admin.auth, job.id).expect(204);
    expect(await JobModel.countDocuments()).toBe(0);
  });

  test('a student gets a 403, an unknown offer a 404', async () => {
    const author = await createCompany();
    const student = await createStudent();
    const job = await postedBy(author);

    await remove(student.auth, job.id).expect(403);
    await remove(author.auth, 'unknown-offer').expect(404);
    expect(await JobModel.countDocuments()).toBe(1);
  });
});
