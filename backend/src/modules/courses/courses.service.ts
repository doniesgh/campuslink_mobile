import { conflict, notFound } from '../../lib/http-error';
import { campusToday, clock, resolveRelativeTime, type RelativeTime } from './campus-time';
import {
  AssignmentSubmissionModel,
  CourseAttendanceModel,
  CourseModel,
  CourseResourceModel,
  type Course,
  type CourseResource,
} from './courses.model';

// What the API sends (the shapes the app's course_models.dart reads).
// Instants are ISO-8601 UTC strings.

export interface ProfessorJson {
  title: string;
  name: string;
  office: string;
  email: string;
  isOnline: boolean;
}

export type CourseResourceJson =
  | {
      type: 'document';
      id: string;
      title: string;
      format: string;
      sizeBytes: number;
      updatedAt: string;
    }
  | { type: 'video'; id: string; title: string; durationSeconds: number; quality: string }
  | {
      type: 'assignment';
      id: string;
      title: string;
      description: string;
      dueAt: string;
      points: number;
      isMandatory: boolean;
      /** The student's repository, or null when not submitted yet. */
      submittedRepoUrl: string | null;
    };

export interface CourseJson {
  id: string;
  code: string;
  location: string;
  title: string;
  term: string;
  track: string;
  professor: ProfessorJson;
  modules: { number: number; title: string; hours: number; isCompleted: boolean }[];
  lecturesHeld: number;
  lectureCount: number;
  nextQuiz: { topic: string; date: string } | null;
  resources: CourseResourceJson[];
  community: { onlineCount: number; onlineClassmates: string[] };
  /** The student logged attendance for the latest session. */
  isPresent: boolean;
}

export interface SubmissionJson {
  assignmentId: string;
  repoUrl: string;
  submittedAt: string;
}

/** Everything a course view depends on for one student, at one moment. */
interface ViewContext {
  today: Date;
  present: Map<string, boolean>;
  repoUrls: Map<string, string>;
}

const at = (time: RelativeTime | null | undefined, today: Date): string =>
  resolveRelativeTime(time ?? { inDays: 0, time: '00:00' }, today).toISOString();

function toResourceJson(r: CourseResource, ctx: ViewContext): CourseResourceJson {
  switch (r.type) {
    case 'document':
      return {
        type: 'document',
        id: r._id,
        title: r.title,
        format: r.format ?? '',
        sizeBytes: r.sizeBytes ?? 0,
        updatedAt: at(r.updated, ctx.today),
      };
    case 'video':
      return {
        type: 'video',
        id: r._id,
        title: r.title,
        durationSeconds: r.durationSeconds ?? 0,
        quality: r.quality ?? '',
      };
    case 'assignment':
      return {
        type: 'assignment',
        id: r._id,
        title: r.title,
        description: r.description ?? '',
        dueAt: at(r.due, ctx.today),
        points: r.points ?? 0,
        isMandatory: r.isMandatory ?? true,
        submittedRepoUrl: ctx.repoUrls.get(r._id) ?? null,
      };
  }
}

function toCourseJson(c: Course, resources: CourseResource[], ctx: ViewContext): CourseJson {
  return {
    id: c._id,
    code: c.code,
    location: c.location,
    title: c.title,
    term: c.term,
    track: c.track,
    professor: {
      title: c.professor.title,
      name: c.professor.name,
      office: c.professor.office,
      email: c.professor.email,
      isOnline: c.professor.isOnline,
    },
    modules: c.modules.map((m, i) => ({
      number: i + 1,
      title: m.title,
      hours: m.hours,
      isCompleted: m.isCompleted,
    })),
    lecturesHeld: c.lecturesHeld,
    lectureCount: c.lectureCount,
    nextQuiz: c.nextQuiz
      ? { topic: c.nextQuiz.topic, date: at(c.nextQuiz.at, ctx.today) }
      : null,
    resources: resources.map((r) => toResourceJson(r, ctx)),
    community: {
      onlineCount: c.community.onlineCount,
      onlineClassmates: [...c.community.onlineClassmates],
    },
    isPresent: ctx.present.get(c._id) ?? false,
  };
}

/** The student's courses, with their own attendance and submissions applied. */
export async function listCourses(userId: string): Promise<CourseJson[]> {
  const [courses, resources, attendance, submissions] = await Promise.all([
    CourseModel.find().sort({ position: 1 }).lean<Course[]>(),
    CourseResourceModel.find().sort({ position: 1 }).lean<CourseResource[]>(),
    CourseAttendanceModel.find({ userId }).lean(),
    AssignmentSubmissionModel.find({ userId }).lean(),
  ]);
  const ctx: ViewContext = {
    today: campusToday(clock.now()),
    present: new Map(attendance.map((a) => [a.courseId, a.present])),
    repoUrls: new Map(submissions.map((s) => [s.assignmentId, s.repoUrl])),
  };
  return courses.map((c) =>
    toCourseJson(
      c,
      resources.filter((r) => r.courseId === c._id),
      ctx,
    ),
  );
}

/** Logs (or undoes) the student's attendance for the latest session of a course. */
export async function setAttendance(
  userId: string,
  courseId: string,
  present: boolean,
): Promise<void> {
  if (!(await CourseModel.exists({ _id: courseId }))) throw notFound('Course not found.');
  await CourseAttendanceModel.updateOne(
    { userId, courseId },
    { $set: { present } },
    { upsert: true },
  );
}

/**
 * Link to download a document. A placeholder for now: files are not stored
 * yet. Videos are streamed and labs handed in, so only documents qualify.
 */
export async function downloadResource(resourceId: string): Promise<{ url: string }> {
  const resource = await CourseResourceModel.findById(resourceId).lean<CourseResource>();
  if (!resource) throw notFound('File not found.');
  if (resource.type !== 'document') throw conflict('Only documents can be downloaded.');
  const extension = (resource.format ?? 'pdf').toLowerCase();
  return {
    url: `https://files.campuspulse.test/courses/${resource.courseId}/${resource._id}.${extension}`,
  };
}

/** Hands in a lab as a repository link (again: replaces the previous link). */
export async function submitAssignment(
  userId: string,
  assignmentId: string,
  repoUrl: string,
): Promise<SubmissionJson> {
  const resource = await CourseResourceModel.findById(assignmentId).lean<CourseResource>();
  if (!resource || resource.type !== 'assignment') throw notFound('Assignment not found.');
  const submission = await AssignmentSubmissionModel.findOneAndUpdate(
    { userId, assignmentId },
    { $set: { repoUrl } },
    { upsert: true, returnDocument: 'after' },
  ).lean();
  return {
    assignmentId,
    repoUrl,
    submittedAt: (submission?.updatedAt ?? clock.now()).toISOString(),
  };
}
