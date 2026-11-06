import { model, Schema } from 'mongoose';

/** One course of a semester, with its raw marks out of 20 (null when not graded). */
export interface StoredCourse {
  /** "CS-401" */
  code: string;
  title: string;
  /** Weight in the semester average. */
  coefficient: number;
  /** ECTS credits earned when the course is validated. */
  credits: number;
  /** Continuous assessment mark. */
  continuous: number | null;
  /** Final exam mark (null for courses without an exam). */
  exam: number | null;
}

/**
 * One published semester. It is stored relative to the current one: the
 * semester number, academic year, id and publication date are computed from
 * the request date (see grades.service.ts), like the app's mock.
 */
export interface StoredSemester {
  /** 1 = the semester just before the current one, 2 = the one before, etc. */
  semestersAgo: number;
  courses: StoredCourse[];
  /** Position in the cohort (1 = best), when published. */
  rank: number | null;
  cohortSize: number | null;
  /** Who signed the official record. Null while the results are provisional. */
  signedBy: string | null;
  /** Size of the signed PDF transcript. */
  documentSizeMb: number | null;
  /** Marks last updated this many hours before the request. Null: on the usual publication day. */
  updatedHoursAgo: number | null;
}

const mark = { type: Number, min: 0, max: 20, default: null };

const courseSchema = new Schema<StoredCourse>(
  {
    code: { type: String, required: true, trim: true },
    title: { type: String, required: true, trim: true },
    coefficient: { type: Number, required: true, min: 0 },
    credits: { type: Number, required: true, min: 0 },
    continuous: mark,
    exam: mark,
  },
  { _id: false },
);

const semesterSchema = new Schema<StoredSemester>(
  {
    semestersAgo: { type: Number, required: true, min: 1 },
    courses: { type: [courseSchema], default: [] },
    rank: { type: Number, min: 1, default: null },
    cohortSize: { type: Number, min: 1, default: null },
    signedBy: { type: String, default: null },
    documentSizeMb: { type: Number, min: 0, default: null },
    updatedHoursAgo: { type: Number, min: 0, default: null },
  },
  { _id: false },
);

/** The marks of one student: one document per student. */
const transcriptSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    semesters: { type: [semesterSchema], default: [] },
  },
  { timestamps: true },
);

export const TranscriptModel = model('Transcript', transcriptSchema);
