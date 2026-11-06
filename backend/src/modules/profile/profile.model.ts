import { model, Schema, type Types } from 'mongoose';

/**
 * Academic data of a student, set by the school. The name, email and ENT ID
 * live on the user; the semester, academic year and card validity are
 * computed from the request date; credits, rank and honours come from the
 * transcript.
 */
export interface ProfileData {
  /** 1 to 5 (ESPRIT's engineering cycle). */
  yearOfStudy: number;
  /** "Software Engineering" */
  program: string;
  /** Short form printed on the card: "Software Eng." */
  programShort: string;
  /** Class name without the year: "BI" for 4BI. */
  classGroup: string;
  /** "ESPRIT Ghazela" */
  campus: string;
  /** Where the "on campus" indicator points: "Ghazela Technopark". */
  campusLocation: string;
  /** On a 4.0 scale. The transcript has marks out of 20, so it is stored. */
  gpa: number;
  isOnCampus: boolean;
  /** ID checked by the school administration. */
  isVerified: boolean;
  nfcReady: boolean;
  hasEspritKey: boolean;
}

/**
 * What a student without a profile document gets: a 1st-year student of the
 * common core (class 1A) on the main campus, not verified yet, with no GPA.
 */
export const DEFAULT_PROFILE: Readonly<ProfileData> = Object.freeze({
  yearOfStudy: 1,
  program: 'Engineering Common Core',
  programShort: 'Common Core',
  classGroup: 'A',
  campus: 'ESPRIT Ghazela',
  campusLocation: 'Ghazela Technopark',
  gpa: 0,
  isOnCampus: false,
  isVerified: false,
  nfcReady: false,
  hasEspritKey: false,
});

const d = DEFAULT_PROFILE;

// One document per student. Missing fields fall back to the default profile.
const profileSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, unique: true },
    yearOfStudy: { type: Number, required: true, min: 1, max: 5, default: d.yearOfStudy },
    program: { type: String, required: true, trim: true, default: d.program },
    programShort: { type: String, required: true, trim: true, default: d.programShort },
    classGroup: { type: String, required: true, trim: true, default: d.classGroup },
    campus: { type: String, required: true, trim: true, default: d.campus },
    campusLocation: { type: String, required: true, trim: true, default: d.campusLocation },
    gpa: { type: Number, required: true, min: 0, max: 4, default: d.gpa },
    isOnCampus: { type: Boolean, required: true, default: d.isOnCampus },
    isVerified: { type: Boolean, required: true, default: d.isVerified },
    nfcReady: { type: Boolean, required: true, default: d.nfcReady },
    hasEspritKey: { type: Boolean, required: true, default: d.hasEspritKey },
  },
  { timestamps: true },
);

export const StudentProfileModel = model('StudentProfile', profileSchema);

/** The stored profile of [userId], or the default one when there is none. */
export async function findProfile(userId: string | Types.ObjectId): Promise<ProfileData> {
  // Not lean: a hydrated document fills missing fields with their defaults.
  const doc = await StudentProfileModel.findOne({ userId });
  if (!doc) return { ...DEFAULT_PROFILE };
  return {
    yearOfStudy: doc.yearOfStudy,
    program: doc.program,
    programShort: doc.programShort,
    classGroup: doc.classGroup,
    campus: doc.campus,
    campusLocation: doc.campusLocation,
    gpa: doc.gpa,
    isOnCampus: doc.isOnCampus,
    isVerified: doc.isVerified,
    nfcReady: doc.nfcReady,
    hasEspritKey: doc.hasEspritKey,
  };
}
