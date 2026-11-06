/**
 * The app's grading rules (lib/features/grades/domain/grading.dart), ported
 * only for the Profile stats (credits earned, rank, honours). The transcript
 * itself is sent as raw marks and the app computes everything it shows, so
 * the two must follow exactly the same rules: change both files together.
 */

const PASS_MARK = 10;
const HONOR_ROLL_MARK = 14;
const CONTINUOUS_WEIGHT = 0.4;
const EXAM_WEIGHT = 0.6;

export interface Marks {
  coefficient: number;
  credits: number;
  continuous: number | null;
  exam: number | null;
}

/**
 * Rounds a mark to 2 decimals, half away from zero (12.345 → 12.35). The
 * epsilon absorbs floating-point noise (12.345 is stored as 12.3449999…).
 */
export function roundGrade(value: number): number {
  const scaled = value * 100;
  const nudged = scaled + (scaled >= 0 ? 1e-6 : -1e-6);
  // Math.round rounds -0.5 up; Dart's round() goes away from zero.
  return (Math.sign(nudged) * Math.round(Math.abs(nudged))) / 100;
}

/** 40% continuous + 60% exam, or the only mark available. Null without any mark. */
export function courseAverage(continuous: number | null, exam: number | null): number | null {
  if (continuous !== null && exam !== null) {
    return roundGrade(continuous * CONTINUOUS_WEIGHT + exam * EXAM_WEIGHT);
  }
  const only = continuous ?? exam;
  return only === null ? null : roundGrade(only);
}

/** Σ(mark × weight) / Σ(weight), rounded. Null when the total weight is zero. */
export function weightedAverage(marks: readonly (readonly [number, number])[]): number | null {
  let sum = 0;
  let weights = 0;
  for (const [mark, weight] of marks) {
    sum += mark * weight;
    weights += weight;
  }
  return weights <= 0 ? null : roundGrade(sum / weights);
}

/** "Top X%" of the cohort, rounded up (rank 7 of 142 → 5). Null when not published or invalid. */
export function topPercent(rank: number | null, cohortSize: number | null): number | null {
  if (rank === null || cohortSize === null || cohortSize <= 0 || rank < 1 || rank > cohortSize) {
    return null;
  }
  return Math.floor((rank * 100 + cohortSize - 1) / cohortSize);
}

export interface SemesterSummary {
  /** Coefficient-weighted average of the rounded course averages. Null when nothing is graded. */
  average: number | null;
  creditsEarned: number;
  /** Complete, average ≥ 14 and every course validated on its own. */
  isHonorRoll: boolean;
}

/**
 * Average, credits and honor roll of a semester. A course below 10 is
 * compensated (credits earned) when the whole semester is validated.
 */
export function evaluateSemester(courses: readonly Marks[]): SemesterSummary {
  const averages = courses.map((c) => courseAverage(c.continuous, c.exam));
  const graded: [number, number][] = [];
  averages.forEach((avg, i) => {
    if (avg !== null) graded.push([avg, courses[i].coefficient]);
  });
  const average = weightedAverage(graded);
  const complete = averages.every((a) => a !== null);
  const validated = complete && average !== null && average >= PASS_MARK;

  let creditsEarned = 0;
  averages.forEach((avg, i) => {
    if (avg !== null && (avg >= PASS_MARK || validated)) creditsEarned += courses[i].credits;
  });

  return {
    average,
    creditsEarned,
    isHonorRoll:
      complete &&
      average !== null &&
      average >= HONOR_ROLL_MARK &&
      averages.every((a) => a !== null && a >= PASS_MARK),
  };
}
