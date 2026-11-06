import { model, Schema } from 'mongoose';

import type { RelativeTime } from './campus-time';

// Catalog: the courses of the class group and their resources, the same for
// every student. Dates are stored relative to the request day (see
// RelativeTime) and resolved when the courses are read.

export interface Professor {
  /** "Prof.", "Dr." */
  title: string;
  /** "Ben Ali" (without the title). */
  name: string;
  office: string;
  email: string;
  isOnline: boolean;
}

export interface CourseModule {
  title: string;
  hours: number;
  isCompleted: boolean;
}

export interface Course {
  /** Slug used by the app and the timetable ('genie-logiciel'). */
  _id: string;
  /** Order in the course list. */
  position: number;
  code: string;
  location: string;
  title: string;
  term: string;
  track: string;
  professor: Professor;
  /** Syllabus, in order. */
  modules: CourseModule[];
  lecturesHeld: number;
  lectureCount: number;
  nextQuiz: { topic: string; at: RelativeTime } | null;
  community: { onlineCount: number; onlineClassmates: string[] };
}

export const RESOURCE_TYPES = ['document', 'video', 'assignment'] as const;
export type ResourceType = (typeof RESOURCE_TYPES)[number];

/** A handout, recording or graded lab. Only the fields of its `type` are set. */
export interface CourseResource {
  /** Slug used by the app ('gl-lesson-7'). */
  _id: string;
  courseId: string;
  /** Order within the course. */
  position: number;
  type: ResourceType;
  title: string;
  // document
  format?: string | null;
  sizeBytes?: number | null;
  updated?: RelativeTime | null;
  // video
  durationSeconds?: number | null;
  quality?: string | null;
  // assignment
  description?: string | null;
  due?: RelativeTime | null;
  points?: number | null;
  isMandatory?: boolean | null;
}

const relativeTimeSchema = new Schema<RelativeTime>(
  {
    inDays: { type: Number, default: null },
    weekday: { type: Number, default: null, min: 1, max: 7 },
    time: { type: String, required: true, match: /^\d{2}:\d{2}$/ },
  },
  { _id: false },
);

const courseSchema = new Schema<Course>(
  {
    _id: { type: String, required: true },
    position: { type: Number, required: true },
    code: { type: String, required: true },
    location: { type: String, required: true },
    title: { type: String, required: true },
    term: { type: String, required: true },
    track: { type: String, required: true },
    professor: {
      type: new Schema<Professor>(
        {
          title: { type: String, required: true },
          name: { type: String, required: true },
          office: { type: String, required: true },
          email: { type: String, required: true },
          isOnline: { type: Boolean, default: false },
        },
        { _id: false },
      ),
      required: true,
    },
    modules: {
      type: [
        new Schema<CourseModule>(
          {
            title: { type: String, required: true },
            hours: { type: Number, required: true },
            isCompleted: { type: Boolean, default: false },
          },
          { _id: false },
        ),
      ],
      default: [],
    },
    lecturesHeld: { type: Number, required: true },
    lectureCount: { type: Number, required: true },
    nextQuiz: {
      type: new Schema(
        {
          topic: { type: String, required: true },
          at: { type: relativeTimeSchema, required: true },
        },
        { _id: false },
      ),
      default: null,
    },
    community: {
      type: new Schema(
        {
          onlineCount: { type: Number, default: 0 },
          onlineClassmates: { type: [String], default: [] },
        },
        { _id: false },
      ),
      required: true,
    },
  },
  { timestamps: true },
);

export const CourseModel = model<Course>('Course', courseSchema);

const resourceSchema = new Schema<CourseResource>(
  {
    _id: { type: String, required: true },
    courseId: { type: String, ref: 'Course', required: true, index: true },
    position: { type: Number, required: true },
    // A path named `type` must be declared this way in Mongoose.
    type: { type: String, enum: RESOURCE_TYPES, required: true },
    title: { type: String, required: true },
    format: { type: String, default: null },
    sizeBytes: { type: Number, default: null },
    updated: { type: relativeTimeSchema, default: null },
    durationSeconds: { type: Number, default: null },
    quality: { type: String, default: null },
    description: { type: String, default: null },
    due: { type: relativeTimeSchema, default: null },
    points: { type: Number, default: null },
    isMandatory: { type: Boolean, default: null },
  },
  { timestamps: true },
);

export const CourseResourceModel = model<CourseResource>('CourseResource', resourceSchema);

// Personal state: one student never sees another's.

/** Attendance a student logged for the latest session of a course. */
const attendanceSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    courseId: { type: String, ref: 'Course', required: true },
    present: { type: Boolean, required: true },
  },
  { timestamps: true },
);
attendanceSchema.index({ userId: 1, courseId: 1 }, { unique: true });

export const CourseAttendanceModel = model('CourseAttendance', attendanceSchema);

/** A lab handed in as a repository link. Submitting again replaces the link. */
const submissionSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    assignmentId: { type: String, ref: 'CourseResource', required: true },
    repoUrl: { type: String, required: true },
  },
  { timestamps: true },
);
submissionSchema.index({ userId: 1, assignmentId: 1 }, { unique: true });

export const AssignmentSubmissionModel = model('AssignmentSubmission', submissionSchema);
