import { model, Schema, Types, type HydratedDocument, type InferSchemaType } from 'mongoose';

const missionItemSchema = new Schema(
  {
    title: { type: String, required: true },
    description: { type: String, required: true },
  },
  { _id: false },
);

/** The last AI summary of an offer (POST /jobs/:id/summary), cleared when the offer is edited. */
const aiSummarySchema = new Schema(
  {
    summary: { type: String, required: true },
    keyPoints: { type: [String], default: [] },
    skills: { type: [String], default: [] },
    idealFor: { type: String, default: '' },
    model: { type: String, required: true },
    /** The language it was written in ('fr' | 'en'): a user of the other language gets a new one. */
    locale: { type: String, required: true },
    generatedAt: { type: Date, required: true },
  },
  { _id: false },
);

/**
 * An internship / PFE / job offer. The seeded catalogue is rich (stats,
 * workspace, mission items, match); offers posted by a company or an admin
 * (POST /jobs) only have what the form asks for: every other field is
 * optional, with an empty default the app knows how to hide.
 */
const jobSchema = new Schema(
  {
    /** Readable id for the seeded offers (e.g. "instadeep-ml"), an ObjectId string for posted ones. */
    _id: { type: String, default: () => new Types.ObjectId().toHexString() },

    /** Shown above the title when the offer is featured, null otherwise. */
    featuredLabel: { type: String, default: null },
    title: { type: String, required: true },
    company: { type: String, required: true },
    location: { type: String, default: '' },
    tags: { type: [String], default: [] },
    stipendTnd: { type: Number, default: null },
    durationMonths: { type: Number, default: null },

    /** Free text such as "Feb – Jul 2025". */
    period: { type: String, default: '' },
    labGroup: { type: String, default: null },
    labGroupNote: { type: String, default: null },
    workspaceTitle: { type: String, default: null },
    workspaceBadges: { type: [String], default: [] },

    /** The description of the offer (`description` in the API's bodies). */
    mission: { type: String, required: true },
    missionItems: { type: [missionItemSchema], default: [] },
    matchPercent: { type: Number, default: null },
    criteria: { type: [String], default: [] },
    skills: { type: [String], default: [] },

    /** The company or admin who posted it; null for the seeded catalogue. */
    authorId: { type: Schema.Types.ObjectId, ref: 'User', default: null, index: true },
    aiSummary: { type: aiSummarySchema, default: null },
  },
  { timestamps: true },
);

export type Job = InferSchemaType<typeof jobSchema>;
export type JobDocument = HydratedDocument<Job>;

export const JobModel = model('Job', jobSchema);

/** One per student and offer: the unique index makes a second application fail. */
const jobApplicationSchema = new Schema(
  {
    jobId: { type: String, ref: 'Job', required: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true },
);

jobApplicationSchema.index({ userId: 1, jobId: 1 }, { unique: true });

export const JobApplicationModel = model('JobApplication', jobApplicationSchema);
