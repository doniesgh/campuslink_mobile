import { z } from 'zod';

/**
 * Limits of a posted offer. The app's form checks the same rules, with the
 * same messages, before sending: lib/features/jobs/domain/job_form_rules.dart.
 * Change both together.
 */
export const JOB_LIMITS = {
  titleMin: 3,
  titleMax: 120,
  companyMin: 2,
  companyMax: 100,
  locationMax: 100,
  periodMax: 60,
  descriptionMin: 20,
  descriptionMax: 5000,
  durationMax: 36,
  stipendMax: 100_000,
  listItemMax: 40,
  skillsMax: 15,
  tagsMax: 6,
} as const;

const L = JOB_LIMITS;

// Shown as-is in the app (the Jobs screens are in English).
export const JOB_MESSAGES = {
  titleMissing: 'Enter a title.',
  titleTooShort: `The title needs at least ${L.titleMin} characters.`,
  titleTooLong: `The title can have at most ${L.titleMax} characters.`,
  companyTooShort: `The company name needs at least ${L.companyMin} characters.`,
  companyTooLong: `The company name can have at most ${L.companyMax} characters.`,
  locationTooLong: `The location can have at most ${L.locationMax} characters.`,
  periodTooLong: `The period can have at most ${L.periodMax} characters.`,
  descriptionMissing: 'Enter a description.',
  descriptionTooShort: `The description needs at least ${L.descriptionMin} characters.`,
  descriptionTooLong: `The description can have at most ${L.descriptionMax} characters.`,
  duration: `The duration is a whole number of months, from 1 to ${L.durationMax}.`,
  stipend: `The stipend is a whole number of TND, from 0 to ${L.stipendMax}.`,
  skills: `At most ${L.skillsMax} skills, of ${L.listItemMax} characters each.`,
  tags: `At most ${L.tagsMax} tags, of ${L.listItemMax} characters each.`,
  nothingToUpdate: 'Nothing to update.',
} as const;

const M = JOB_MESSAGES;

const optionalText = (max: number, message: string) =>
  z.string({ error: message }).trim().max(max, message).optional();

/** A list of short labels: trimmed, blanks and duplicates dropped. */
const labels = (max: number, message: string) =>
  z
    .array(z.string({ error: message }).trim().max(L.listItemMax, message), { error: message })
    .transform((items) => [...new Set(items.filter(Boolean))])
    .refine((items) => items.length <= max, message)
    .optional();

const wholeNumber = (min: number, max: number, message: string) =>
  z.int({ error: message }).min(min, message).max(max, message).nullish();

/** POST /jobs. Only the title and the description are required. */
export const jobCreateSchema = z.object({
  title: z
    .string({ error: M.titleMissing })
    .trim()
    .min(1, M.titleMissing)
    .min(L.titleMin, M.titleTooShort)
    .max(L.titleMax, M.titleTooLong),
  /** Default: the author's display name. */
  company: z
    .string({ error: M.companyTooShort })
    .trim()
    .min(L.companyMin, M.companyTooShort)
    .max(L.companyMax, M.companyTooLong)
    .optional(),
  location: optionalText(L.locationMax, M.locationTooLong),
  period: optionalText(L.periodMax, M.periodTooLong),
  description: z
    .string({ error: M.descriptionMissing })
    .trim()
    .min(1, M.descriptionMissing)
    .min(L.descriptionMin, M.descriptionTooShort)
    .max(L.descriptionMax, M.descriptionTooLong),
  durationMonths: wholeNumber(1, L.durationMax, M.duration),
  stipendTnd: wholeNumber(0, L.stipendMax, M.stipend),
  skills: labels(L.skillsMax, M.skills),
  tags: labels(L.tagsMax, M.tags),
});

export type JobCreateInput = z.infer<typeof jobCreateSchema>;

/** PATCH /jobs/:id: any of the fields above; null clears a number. */
export const jobUpdateSchema = jobCreateSchema
  .partial()
  .refine((value) => Object.values(value).some((v) => v !== undefined), M.nothingToUpdate);

export type JobUpdateInput = z.infer<typeof jobUpdateSchema>;
