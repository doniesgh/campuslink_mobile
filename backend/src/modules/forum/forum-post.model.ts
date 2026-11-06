import { model, Schema, Types, type InferSchemaType } from 'mongoose';

/** Forum sections, sent as the app's `PostCategory` names. */
export const POST_CATEGORIES = ['carpool', 'lostFound', 'idea'] as const;
export type PostCategory = (typeof POST_CATEGORIES)[number];

/**
 * A post in one of the forum sections. The author is shown as a name and an
 * info string ("5A - Informatique"); posts published from the app also keep
 * the author's account id (the demo posts have none). Ids are strings so the
 * demo posts keep the app's ids ("post-1"); new posts get an ObjectId-like
 * string.
 */
const forumPostSchema = new Schema(
  {
    _id: { type: String, default: () => new Types.ObjectId().toHexString() },
    authorId: { type: Schema.Types.ObjectId, ref: 'User', default: null },
    authorName: { type: String, required: true, trim: true },
    authorInfo: { type: String, required: true, trim: true },
    category: { type: String, enum: POST_CATEGORIES, required: true },

    /** Short badge text: "2 places", "Trouvé", "Proposition". */
    tag: { type: String, required: true },
    body: { type: String, required: true },

    /** Route or location shown under the post ("Passage → Ghazela"). */
    place: { type: String, default: null },

    /**
     * Base count of an idea (the demo ideas are seeded with one). Students'
     * votes are stored as IdeaVote documents and added to it by the API.
     */
    upvotes: { type: Number, default: 0, min: 0 },
    comments: { type: Number, default: 0, min: 0 },

    /** Moderation status of an idea ("En examen BDE"). */
    status: { type: String, default: null },
    postedAt: { type: Date, required: true },
  },
  { timestamps: true },
);

forumPostSchema.index({ postedAt: -1 });

export type ForumPost = InferSchemaType<typeof forumPostSchema>;

export const ForumPostModel = model('ForumPost', forumPostSchema);

/** What the API sends for a post (the shape the app's ForumPostModel.fromJson reads). */
export interface PublicForumPost {
  id: string;
  authorName: string;
  authorInfo: string;
  category: PostCategory;
  tag: string;
  body: string;
  place: string | null;
  /** Base count + students' votes. */
  upvotes: number;
  comments: number;
  status: string | null;
  postedAt: string;

  /** Whether the student asking voted for this idea (always false for other posts). */
  isUpvotedByMe: boolean;
}

/** Students' votes on an idea, as counted by the service. */
export interface IdeaVotes {
  count: number;
  isUpvotedByMe: boolean;
}

const NO_VOTES: IdeaVotes = { count: 0, isUpvotedByMe: false };

export const toPublicPost = (post: ForumPost, votes: IdeaVotes = NO_VOTES): PublicForumPost => ({
  id: post._id,
  authorName: post.authorName,
  authorInfo: post.authorInfo,
  category: post.category,
  tag: post.tag,
  body: post.body,
  place: post.place ?? null,
  upvotes: post.upvotes + votes.count,
  comments: post.comments,
  status: post.status ?? null,
  postedAt: post.postedAt.toISOString(),
  isUpvotedByMe: votes.isUpvotedByMe,
});
