import { model, Schema, type InferSchemaType } from 'mongoose';

/**
 * A student's upvote on an idea of the forum. The API adds the number of
 * votes to the idea's base `upvotes` (the count the demo ideas are seeded
 * with), so seeding again never loses real votes.
 */
const ideaVoteSchema = new Schema(
  {
    ideaId: { type: String, ref: 'ForumPost', required: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  },
  { timestamps: true },
);

// One vote per student and idea (also serves the per-idea counts).
ideaVoteSchema.index({ ideaId: 1, userId: 1 }, { unique: true });

export type IdeaVote = InferSchemaType<typeof ideaVoteSchema>;

export const IdeaVoteModel = model('IdeaVote', ideaVoteSchema);
