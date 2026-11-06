import { conflict, notFound } from '../../lib/http-error';
import { JobApplicationModel, JobModel, type JobDocument } from './jobs.model';

const JOB_NOT_FOUND = 'Job not found.';
const ALREADY_APPLIED = 'You already applied to this offer.';

/** What the API sends for an offer (the shape the app's JobModel.fromJson reads). */
export interface JobJson {
  id: string;
  featuredLabel: string | null;
  title: string;
  company: string;
  location: string;
  tags: string[];
  stipendTnd: number;
  durationMonths: number;
  period: string;
  labGroup: string;
  labGroupNote: string;
  workspaceTitle: string;
  workspaceBadges: string[];
  mission: string;
  missionItems: { title: string; description: string }[];
  matchPercent: number;
  criteria: string[];
  skills: string[];
  /** Whether the signed-in student already applied (so the app shows "Applied"). */
  hasApplied: boolean;
}

export const toJobJson = (job: JobDocument, hasApplied = false): JobJson => ({
  id: job.id as string,
  featuredLabel: job.featuredLabel ?? null,
  title: job.title,
  company: job.company,
  location: job.location,
  tags: [...job.tags],
  stipendTnd: job.stipendTnd,
  durationMonths: job.durationMonths,
  period: job.period,
  labGroup: job.labGroup,
  labGroupNote: job.labGroupNote,
  workspaceTitle: job.workspaceTitle,
  workspaceBadges: [...job.workspaceBadges],
  mission: job.mission,
  missionItems: job.missionItems.map(({ title, description }) => ({ title, description })),
  matchPercent: job.matchPercent,
  criteria: [...job.criteria],
  skills: [...job.skills],
  hasApplied,
});

/** Every offer, best match first, with the student's own application state. */
export async function listJobs(userId: string): Promise<JobJson[]> {
  const [jobs, applied] = await Promise.all([
    JobModel.find().sort({ matchPercent: -1, _id: 1 }),
    JobApplicationModel.distinct('jobId', { userId }),
  ]);
  const appliedIds = new Set(applied.map(String));
  return jobs.map((job) => toJobJson(job, appliedIds.has(job.id as string)));
}

export async function getJob(jobId: string, userId: string): Promise<JobJson> {
  const [job, applied] = await Promise.all([
    JobModel.findById(jobId),
    JobApplicationModel.exists({ jobId, userId }),
  ]);
  if (!job) throw notFound(JOB_NOT_FOUND);
  return toJobJson(job, applied !== null);
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
