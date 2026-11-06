import { model, Schema, type HydratedDocument, type InferSchemaType } from 'mongoose';

const missionItemSchema = new Schema(
  {
    title: { type: String, required: true },
    description: { type: String, required: true },
  },
  { _id: false },
);

/** An internship / PFE offer. The catalog is the same for every student. */
const jobSchema = new Schema(
  {
    /** Readable id used in the app's URLs and notifications, e.g. "instadeep-ml". */
    _id: { type: String, required: true },

    /** Shown above the title when the offer is featured, null otherwise. */
    featuredLabel: { type: String, default: null },
    title: { type: String, required: true },
    company: { type: String, required: true },
    location: { type: String, required: true },
    tags: { type: [String], default: [] },
    stipendTnd: { type: Number, required: true },
    durationMonths: { type: Number, required: true },

    /** Free text such as "Feb – Jul 2025". */
    period: { type: String, required: true },
    labGroup: { type: String, required: true },
    labGroupNote: { type: String, required: true },
    workspaceTitle: { type: String, required: true },
    workspaceBadges: { type: [String], default: [] },
    mission: { type: String, required: true },
    missionItems: { type: [missionItemSchema], default: [] },
    matchPercent: { type: Number, required: true },
    criteria: { type: [String], default: [] },
    skills: { type: [String], default: [] },
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
