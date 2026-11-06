import { unauthorized } from '../../lib/http-error';
import {
  academicYearStartFor,
  formatAcademicYear,
  semesterFor,
  tunisTime,
} from '../profile/academic-calendar';
import { findProfile } from '../profile/profile.model';
import { UserModel, type UserDocument } from '../users/user.model';
import { TranscriptModel, type StoredCourse, type StoredSemester } from './transcript.model';

// The shapes the app's AcademicTranscriptModel.fromJson reads. Only raw
// marks are sent: the app computes averages, mentions and credits itself.

export type CourseGradeJson = StoredCourse;

export interface SemesterRecordJson {
  /** "2025-2026-s6" */
  id: string;
  /** "2025–2026" */
  academicYear: string;
  number: number;
  /** ISO-8601 UTC */
  updatedAt: string;
  rank: number | null;
  cohortSize: number | null;
  signedBy: string | null;
  documentSizeMb: number | null;
  courses: CourseGradeJson[];
}

export interface TranscriptJson {
  /** The student's ENT ID, null when the school has not assigned one yet. */
  studentId: string | null;
  /** Most recent first. */
  semesters: SemesterRecordJson[];
}

const HOUR_MS = 60 * 60 * 1000;

/** GET /grades/transcript: the signed-in student's published semesters on [now]. */
export async function getTranscript(userId: string, now: Date): Promise<TranscriptJson> {
  const [user, profile] = await Promise.all([UserModel.findById(userId), findProfile(userId)]);
  // A valid token for a deleted account: treat it as an expired session.
  if (!user) throw unauthorized();
  return transcriptOf(user, profile.yearOfStudy, now);
}

/**
 * The published semesters of [user], a student in [yearOfStudy] (from the
 * profile, so Grades and Profile agree on the current semester). Semester
 * numbers count back from the current one; any before S1 is dropped.
 */
export async function transcriptOf(
  user: UserDocument,
  yearOfStudy: number,
  now: Date,
): Promise<TranscriptJson> {
  const stored = await TranscriptModel.findOne({ userId: user._id }).lean<{
    semesters: StoredSemester[];
  }>();
  const current = semesterFor(yearOfStudy, now);
  const currentYearStart = academicYearStartFor(now);

  const semesters = [...(stored?.semesters ?? [])]
    .sort((a, b) => a.semestersAgo - b.semestersAgo)
    .map((s) => ({ s, number: current - s.semestersAgo }))
    .filter(({ number }) => number >= 1)
    .map(({ s, number }) => toRecord(s, number, yearOfStudy, currentYearStart, now));

  return { studentId: user.studentId ?? null, semesters };
}

/**
 * Semester [number] of a student in [yearOfStudy] whose current academic
 * year starts in [currentYearStart]. Unless [s] says when it was updated,
 * results are dated when they are usually published: 7 February 14:30 for a
 * fall semester, 3 July 10:00 for a spring one (Tunisia time).
 */
function toRecord(
  s: StoredSemester,
  number: number,
  yearOfStudy: number,
  currentYearStart: number,
  now: Date,
): SemesterRecordJson {
  const start = currentYearStart - (yearOfStudy - Math.ceil(number / 2));
  const fall = number % 2 === 1;
  const updatedAt =
    s.updatedHoursAgo !== null && s.updatedHoursAgo !== undefined
      ? new Date(now.getTime() - s.updatedHoursAgo * HOUR_MS)
      : fall
        ? tunisTime(start + 1, 2, 7, 14, 30)
        : tunisTime(start + 1, 7, 3, 10);
  return {
    id: `${start}-${start + 1}-s${number}`,
    academicYear: formatAcademicYear(start),
    number,
    updatedAt: updatedAt.toISOString(),
    rank: s.rank ?? null,
    cohortSize: s.cohortSize ?? null,
    signedBy: s.signedBy ?? null,
    documentSizeMb: s.documentSizeMb ?? null,
    courses: s.courses.map((c) => ({
      code: c.code,
      title: c.title,
      coefficient: c.coefficient,
      credits: c.credits,
      continuous: c.continuous ?? null,
      exam: c.exam ?? null,
    })),
  };
}
