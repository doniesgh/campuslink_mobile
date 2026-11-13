import { Types } from 'mongoose';

import { conflict, forbidden, notFound, unauthorized } from '../../lib/http-error';
import { localeOfUser, UserModel, type UserRole } from '../users/user.model';
import {
  JobApplicationModel,
  JobModel,
  type ApplicationStatus,
  type JobDocument,
} from './jobs.model';
import type { JobCreateInput, JobUpdateInput } from './jobs.schemas';
import { summariseOffer, type JobSummaryJson } from './jobs.summary';

const JOB_NOT_FOUND = 'Job not found.';
const ALREADY_APPLIED = 'You already applied to this offer.';
const APPLICATION_NOT_FOUND = 'Application not found.';
const ALREADY_DECIDED = 'This application has already been answered.';
export const NOT_YOUR_OFFER = "This offer isn't yours.";

/** Who may post offers (POST /jobs) and manage them (their own; an admin, every offer). */
export const RECRUITER_ROLES: readonly UserRole[] = ['company', 'admin'];

/** What the API sends for an offer (the shape the app's JobModel.fromJson reads). */
export interface JobJson {
  id: string;
  featuredLabel: string | null;
  title: string;
  company: string;
  /** '' when the offer doesn't say. */
  location: string;
  tags: string[];
  /** null when the offer doesn't say (posted offers), as the fields below. */
  stipendTnd: number | null;
  durationMonths: number | null;
  /** '' when the offer doesn't say. */
  period: string;
  labGroup: string | null;
  labGroupNote: string | null;
  workspaceTitle: string | null;
  workspaceBadges: string[];
  mission: string;
  /** The same text as `mission` (the name used in POST / PATCH bodies). */
  description: string;
  missionItems: { title: string; description: string }[];
  matchPercent: number | null;
  criteria: string[];
  skills: string[];
  /** Whether the signed-in student already applied (so the app shows "Applied"). */
  hasApplied: boolean;
  /** The signed-in student's application state for this offer; null when they didn't apply. */
  applicationStatus: ApplicationStatus | null;
  /** The company or admin who posted it; null for the seeded catalogue. */
  authorId: string | null;
  /** Whether the signed-in user may edit and delete it (its author, or an admin). */
  canEdit: boolean;
}

/** The signed-in user, as far as offers are concerned. */
interface Viewer {
  id: string;
  role: UserRole;
}

async function viewerOf(userId: string) {
  const user = await UserModel.findById(userId).select('role locale displayName');
  // A valid token of a deleted account.
  if (!user) throw unauthorized();
  return user;
}

const authorOf = (job: JobDocument): string | null =>
  job.authorId ? String(job.authorId) : null;

/** Its author (still a company) or any admin. */
const canEdit = (job: JobDocument, viewer: Viewer): boolean =>
  viewer.role === 'admin' || (viewer.role === 'company' && authorOf(job) === viewer.id);

export const toJobJson = (
  job: JobDocument,
  viewer: Viewer,
  hasApplied = false,
  applicationStatus: ApplicationStatus | null = null,
): JobJson => ({
  id: job.id as string,
  featuredLabel: job.featuredLabel ?? null,
  title: job.title,
  company: job.company,
  location: job.location ?? '',
  tags: [...job.tags],
  stipendTnd: job.stipendTnd ?? null,
  durationMonths: job.durationMonths ?? null,
  period: job.period ?? '',
  labGroup: job.labGroup ?? null,
  labGroupNote: job.labGroupNote ?? null,
  workspaceTitle: job.workspaceTitle ?? null,
  workspaceBadges: [...job.workspaceBadges],
  mission: job.mission,
  description: job.mission,
  missionItems: job.missionItems.map(({ title, description }) => ({ title, description })),
  matchPercent: job.matchPercent ?? null,
  criteria: [...job.criteria],
  skills: [...job.skills],
  hasApplied: hasApplied || applicationStatus !== null,
  applicationStatus,
  authorId: authorOf(job),
  canEdit: canEdit(job, viewer),
});

/**
 * Every offer: the posted ones first (newest first), then the seeded
 * catalogue, best match first. With the student's own application state.
 */
export async function listJobs(userId: string): Promise<JobJson[]> {
  const [viewer, posted, catalogue, applied] = await Promise.all([
    viewerOf(userId),
    JobModel.find({ authorId: { $ne: null } }).sort({ createdAt: -1, _id: -1 }),
    JobModel.find({ authorId: null }).sort({ matchPercent: -1, _id: 1 }),
    JobApplicationModel.find({ userId }).select('jobId status'),
  ]);
  const statusByJob = new Map(applied.map((a) => [a.jobId, a.status ?? 'pending'] as const));
  return [...posted, ...catalogue].map((job) => {
    const status = statusByJob.get(job.id as string) ?? null;
    return toJobJson(job, viewer, status !== null, status);
  });
}

export async function getJob(jobId: string, userId: string): Promise<JobJson> {
  const [viewer, job, applied] = await Promise.all([
    viewerOf(userId),
    JobModel.findById(jobId),
    JobApplicationModel.findOne({ jobId, userId }).select('status'),
  ]);
  if (!job) throw notFound(JOB_NOT_FOUND);
  return toJobJson(job, viewer, applied !== null, applied ? (applied.status ?? 'pending') : null);
}

/** Posts an offer for the signed-in company or admin (checked by the route). */
export async function createJob(userId: string, input: JobCreateInput): Promise<JobJson> {
  const author = await viewerOf(userId);
  const job = await JobModel.create({
    title: input.title,
    company: input.company ?? author.displayName,
    location: input.location ?? '',
    period: input.period ?? '',
    mission: input.description,
    durationMonths: input.durationMonths ?? null,
    stipendTnd: input.stipendTnd ?? null,
    skills: input.skills ?? [],
    tags: input.tags ?? [],
    authorId: new Types.ObjectId(userId),
  });
  return toJobJson(job, { id: userId, role: author.role });
}

/** The offer [jobId] if [viewer] may change it: 404 when unknown, 403 when it isn't theirs. */
async function editableJob(jobId: string, viewer: Viewer): Promise<JobDocument> {
  const job = await JobModel.findById(jobId);
  if (!job) throw notFound(JOB_NOT_FOUND);
  if (!canEdit(job, viewer)) throw forbidden(NOT_YOUR_OFFER);
  return job;
}

/** Changes the fields sent (null clears a number). Clears the cached AI summary. */
export async function updateJob(
  jobId: string,
  viewer: Viewer,
  input: JobUpdateInput,
): Promise<JobJson> {
  const job = await editableJob(jobId, viewer);
  const { description, ...fields } = input;
  for (const [key, value] of Object.entries(fields)) {
    if (value !== undefined) job.set(key, value);
  }
  if (description !== undefined) job.mission = description;
  job.aiSummary = null;
  await job.save();
  const applied = await JobApplicationModel.findOne({ jobId, userId: viewer.id }).select('status');
  return toJobJson(job, viewer, applied !== null, applied ? (applied.status ?? 'pending') : null);
}

/** Deletes the offer and its applications. */
export async function deleteJob(jobId: string, viewer: Viewer): Promise<void> {
  const job = await editableJob(jobId, viewer);
  await job.deleteOne();
  await JobApplicationModel.deleteMany({ jobId });
}

/**
 * The AI summary of an offer, in the signed-in user's language. Served from
 * the offer's cache when it has one in that language (until the offer is
 * edited); otherwise asked to the AI and cached.
 */
export async function summarizeJob(jobId: string, userId: string): Promise<JobSummaryJson> {
  const [user, job] = await Promise.all([viewerOf(userId), JobModel.findById(jobId)]);
  if (!job) throw notFound(JOB_NOT_FOUND);
  const locale = localeOfUser(user);

  const cache = job.aiSummary;
  if (cache && cache.locale === locale) {
    return {
      summary: cache.summary,
      keyPoints: [...cache.keyPoints],
      skills: [...cache.skills],
      idealFor: cache.idealFor ?? '',
      model: cache.model,
      cached: true,
    };
  }

  const result = await summariseOffer(job, locale);
  // Only if the offer wasn't edited meanwhile, and without touching updatedAt.
  await JobModel.updateOne(
    { _id: job._id, updatedAt: job.updatedAt ?? null },
    { $set: { aiSummary: { ...result, locale, generatedAt: new Date() } } },
    { timestamps: false },
  );
  return { ...result, cached: false };
}

/** MongoDB unique-index violation. */
const isDuplicateKey = (err: unknown) =>
  typeof err === 'object' && err !== null && (err as { code?: unknown }).code === 11000;

/** Records the student's application. A second one (even sent at the same time) is a 409. */
export async function apply(
  jobId: string,
  userId: string,
): Promise<{ jobId: string; appliedAt: string }> {
  if (!(await JobModel.exists({ _id: jobId }))) throw notFound(JOB_NOT_FOUND);
  if (await JobApplicationModel.exists({ jobId, userId })) throw conflict(ALREADY_APPLIED);
  try {
    const application = await JobApplicationModel.create({ jobId, userId });
    return { jobId, appliedAt: application.createdAt.toISOString() };
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict(ALREADY_APPLIED);
    throw err;
  }
}

/** An application as the signed-in student sees it (GET /jobs/applications/mine). */
export interface MyApplicationJson {
  id: string;
  jobId: string;
  status: ApplicationStatus;
  appliedAt: string;
  decidedAt: string | null;
  job: { id: string; title: string; company: string; location: string };
}

/** An application as the offer's company sees it (GET /jobs/:id/applications). */
export interface OfferApplicationJson {
  id: string;
  jobId: string;
  status: ApplicationStatus;
  appliedAt: string;
  decidedAt: string | null;
  applicant: { id: string; displayName: string; email: string };
}

/** The signed-in student's applications, newest first (offers deleted since are skipped). */
export async function listMyApplications(userId: string): Promise<MyApplicationJson[]> {
  const applications = await JobApplicationModel.find({ userId }).sort({ createdAt: -1 });
  const jobs = await JobModel.find({ _id: { $in: applications.map((a) => a.jobId) } }).select(
    'title company location',
  );
  const jobById = new Map(jobs.map((job) => [job.id as string, job]));
  return applications.flatMap((application) => {
    const job = jobById.get(application.jobId);
    if (!job) return [];
    return [
      {
        id: application.id as string,
        jobId: application.jobId,
        status: application.status ?? 'pending',
        appliedAt: application.createdAt.toISOString(),
        decidedAt: application.decidedAt?.toISOString() ?? null,
        job: { id: job.id as string, title: job.title, company: job.company, location: job.location ?? '' },
      },
    ];
  });
}

/** The student withdraws their application. Only while it is pending: 404 if none, 409 once answered. */
export async function cancelApplication(jobId: string, userId: string): Promise<void> {
  const deleted = await JobApplicationModel.findOneAndDelete({ jobId, userId, status: 'pending' });
  if (deleted) return;
  if (await JobApplicationModel.exists({ jobId, userId })) throw conflict(ALREADY_DECIDED);
  throw notFound(APPLICATION_NOT_FOUND);
}

/** Applications received by an offer, newest first. Its author or an admin only (403 otherwise). */
export async function listOfferApplications(
  jobId: string,
  viewer: Viewer,
): Promise<OfferApplicationJson[]> {
  await editableJob(jobId, viewer);
  const applications = await JobApplicationModel.find({ jobId }).sort({ createdAt: -1 });
  const users = await UserModel.find({ _id: { $in: applications.map((a) => a.userId) } }).select(
    'displayName email',
  );
  const userById = new Map(users.map((user) => [user.id as string, user]));
  return applications.map((application) => toOfferApplicationJson(application, userById));
}

type ApplicationDocument = InstanceType<typeof JobApplicationModel>;

function toOfferApplicationJson(
  application: ApplicationDocument,
  userById: Map<string, { displayName: string; email: string }>,
): OfferApplicationJson {
  const userId = String(application.userId);
  const user = userById.get(userId);
  return {
    id: application.id as string,
    jobId: application.jobId,
    status: application.status ?? 'pending',
    appliedAt: application.createdAt.toISOString(),
    decidedAt: application.decidedAt?.toISOString() ?? null,
    applicant: { id: userId, displayName: user?.displayName ?? '', email: user?.email ?? '' },
  };
}

/** The company (or an admin) accepts or refuses a pending application. 409 once it has been answered. */
export async function decideApplication(
  jobId: string,
  applicationId: string,
  viewer: Viewer,
  status: 'accepted' | 'rejected',
): Promise<OfferApplicationJson> {
  await editableJob(jobId, viewer);
  if (!Types.ObjectId.isValid(applicationId)) throw notFound(APPLICATION_NOT_FOUND);
  const updated = await JobApplicationModel.findOneAndUpdate(
    { _id: applicationId, jobId, status: 'pending' },
    { $set: { status, decidedAt: new Date() } },
    { new: true },
  );
  if (!updated) {
    if (await JobApplicationModel.exists({ _id: applicationId, jobId })) throw conflict(ALREADY_DECIDED);
    throw notFound(APPLICATION_NOT_FOUND);
  }
  const user = await UserModel.findById(updated.userId).select('displayName email');
  return toOfferApplicationJson(updated, new Map(user ? [[user.id as string, user]] : []));
}
