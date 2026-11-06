import { model, Schema, Types, type InferSchemaType } from 'mongoose';

/** Forum sections, sent as the app's `PostCategory` names. */
export const POST_CATEGORIES = ['carpool', 'lostFound', 'idea'] as const;
export type PostCategory = (typeof POST_CATEGORIES)[number];

/**
 * A post in one of the forum sections. The author is stored as a name and an
 * info string ("5A - Informatique"), not as a user account. Ids are strings
 * so the demo posts keep the app's ids ("post-1"); new posts get an
 * ObjectId-like string.
 */
const forumPostSchema = new Schema(
  {
    _id: { type: String, default: () => new Types.ObjectId().toHexString() },
    authorName: { type: String, required: true, trim: true },
    authorInfo: { type: String, required: true, trim: true },
    category: { type: String, enum: POST_CATEGORIES, required: true },

    /** Short badge text: "2 places", "Trouvé", "Proposition". */
    tag: { type: String, required: true },
    body: { type: String, required: true },

    /** Route or location shown under the post ("Passage → Ghazela"). */
    place: { type: String, default: null },
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
  upvotes: number;
  comments: number;
  status: string | null;
  postedAt: string;
}

export const toPublicPost = (post: ForumPost): PublicForumPost => ({
  id: post._id,
  authorName: post.authorName,
  authorInfo: post.authorInfo,
  category: post.category,
  tag: post.tag,
  body: post.body,
  place: post.place ?? null,
  upvotes: post.upvotes,
  comments: post.comments,
  status: post.status ?? null,
  postedAt: post.postedAt.toISOString(),
});
