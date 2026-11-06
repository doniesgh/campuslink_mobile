import { unauthorized } from '../../lib/http-error';
import { RideModel } from '../carpool/carpool.model';
import { evaluateSemester, topPercent } from '../grades/grading';
import { transcriptOf } from '../grades/grades.service';
import { NotificationModel } from '../notifications/notification.model';
import { UserModel } from '../users/user.model';
import { academicYearStartFor, cardValidUntil, semesterFor } from './academic-calendar';
import { findProfile } from './profile.model';

/** The shape the app's StudentProfileModel.fromJson reads. */
export interface StudentProfileJson {
  /** ENT ID, null when the school has not assigned one yet. */
  studentId: string | null;
  displayName: string;
  email: string;
  program: string;
  programShort: string;
  /** "4BI" */
  className: string;
  yearOfStudy: number;
  campus: string;
  campusLocation: string;
  /** Overall semester number (S1..S10). */
  semester: number;
  /** 2026 for 2026–2027. */
  academicYearStart: number;
  /** Last day the student card is valid ('YYYY-MM-DD'). */
  validUntil: string;
  ectsCredits: number;
  gpa: number;
  rankTopPercent: number;
  promoYear: number;
  honours: string | null;
  isOnCampus: boolean;
  isVerified: boolean;
  nfcReady: boolean;
  hasEspritKey: boolean;
  unreadNotifications: number;
  hasCarpoolActivity: boolean;
}

/** Shown on the GPA card when the latest semester is on the honor roll. */
const HONOURS = "Dean's List";

/** Rank card value when no semester has a published rank yet. */
const UNRANKED_TOP_PERCENT = 100;

/**
 * GET /profile: the user (name, email, ENT ID) combined with the stored
 * profile (or the default one), on [now]. Credits, rank and honours come
 * from the transcript, so Profile and Grades always agree.
 */
export async function getProfile(userId: string, now: Date): Promise<StudentProfileJson> {
  const [user, profile, unreadNotifications, carpoolActivity] = await Promise.all([
    UserModel.findById(userId),
    findProfile(userId),
    // Live counters from the other modules (the "3 new" badge and the coral dot).
    NotificationModel.countDocuments({ userId, isRead: false }),
    RideModel.exists({ $or: [{ driverId: userId }, { 'seats.passengerId': userId }] }),
  ]);
  // A valid token for a deleted account: treat it as an expired session.
  if (!user) throw unauthorized();

  const { semesters } = await transcriptOf(user, profile.yearOfStudy, now);
  const summaries = semesters.map((s) => evaluateSemester(s.courses));
  const latestRank = semesters
    .map((s) => topPercent(s.rank, s.cohortSize))
    .find((top) => top !== null);
  const yearStart = academicYearStartFor(now);

  return {
    studentId: user.studentId ?? null,
    displayName: user.displayName,
    email: user.email,
    program: profile.program,
    programShort: profile.programShort,
    className: `${profile.yearOfStudy}${profile.classGroup}`,
    yearOfStudy: profile.yearOfStudy,
    campus: profile.campus,
    campusLocation: profile.campusLocation,
    semester: semesterFor(profile.yearOfStudy, now),
    academicYearStart: yearStart,
    validUntil: cardValidUntil(yearStart),
    ectsCredits: summaries.reduce((sum, s) => sum + s.creditsEarned, 0),
    gpa: profile.gpa,
    rankTopPercent: latestRank ?? UNRANKED_TOP_PERCENT,
    promoYear: yearStart + 1,
    honours: summaries[0]?.isHonorRoll ? HONOURS : null,
    isOnCampus: profile.isOnCampus,
    isVerified: profile.isVerified,
    nfcReady: profile.nfcReady,
    hasEspritKey: profile.hasEspritKey,
    unreadNotifications,
    // Drives a ride or booked a seat in one.
    hasCarpoolActivity: carpoolActivity !== null,
  };
}
