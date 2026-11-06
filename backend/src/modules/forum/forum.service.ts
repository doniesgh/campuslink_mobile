import { conflict, notFound, unauthorized } from '../../lib/http-error';
import { StudentProfileModel } from '../profile/profile.model';
import { UserModel } from '../users/user.model';
import { nextLostItemReference } from './forum-counter.model';
import {
  ForumPostModel,
  toPublicPost,
  type ForumPost,
  type PublicForumPost,
} from './forum-post.model';
import type { PublishIdeaInput, PublishLostItemInput } from './forum.schemas';
import { IdeaVoteModel } from './idea-vote.model';
import { LostItemModel, toPublicLostItem, type PublicLostItem } from './lost-item.model';
import { LostItemRequestModel, type PublicLostItemRequest } from './lost-item-request.model';

/** Home shows a short strip of the latest posts, not the whole forum. */
export const HIGHLIGHTS_LIMIT = 10;

const ITEM_GONE = 'This item is no longer listed.';
const ALREADY_SENT =
  'You already sent a request for this item. The security desk will get back to you.';
const IDEA_GONE = "Cette idée n'existe plus.";

/** `authorInfo` of a student whose class is not known yet. */
export const UNKNOWN_CLASS_INFO = 'Étudiant ESPRIT';

/**
 * [posts] in the API shape, seen by [userId]: ideas get their students'
 * votes added to their base count, and whether [userId] voted.
 */
async function withVotes(posts: ForumPost[], userId: string): Promise<PublicForumPost[]> {
  const ideaIds = posts.filter((post) => post.category === 'idea').map((post) => post._id);
  if (ideaIds.length === 0) return posts.map((post) => toPublicPost(post));

  const [counts, mine] = await Promise.all([
    IdeaVoteModel.aggregate<{ _id: string; count: number }>([
      { $match: { ideaId: { $in: ideaIds } } },
      { $group: { _id: '$ideaId', count: { $sum: 1 } } },
    ]),
    IdeaVoteModel.find({ ideaId: { $in: ideaIds }, userId }).select('ideaId').lean(),
  ]);
  const countById = new Map(counts.map((c) => [c._id, c.count]));
  const votedIds = new Set(mine.map((vote) => vote.ideaId));
  return posts.map((post) =>
    toPublicPost(post, {
      count: countById.get(post._id) ?? 0,
      isUpvotedByMe: votedIds.has(post._id),
    }),
  );
}

/** Latest posts across all sections, newest first (Home "Campus Highlights"). */
export async function listHighlights(userId: string): Promise<PublicForumPost[]> {
  const posts = await ForumPostModel.find()
    .sort({ postedAt: -1, _id: -1 })
    .limit(HIGHLIGHTS_LIMIT)
    .lean();
  return withVotes(posts, userId);
}

/** Most upvoted first, then newest (then by id, so the order is stable). */
const byVotesThenNewest = (a: PublicForumPost, b: PublicForumPost): number =>
  b.upvotes - a.upvotes ||
  b.postedAt.localeCompare(a.postedAt) ||
  (a.id < b.id ? 1 : a.id > b.id ? -1 : 0);

/**
 * The ideas of the forum, most upvoted first, then newest. Sorted here
 * because the count includes the votes, which are stored apart.
 */
export async function listIdeas(userId: string): Promise<PublicForumPost[]> {
  const ideas = await ForumPostModel.find({ category: 'idea' }).lean();
  return (await withVotes(ideas, userId)).sort(byVotesThenNewest);
}

/** The signed-in student's name, or 401 for a valid token of a deleted account. */
async function displayNameOf(userId: string): Promise<string> {
  const user = await UserModel.findById(userId).select('displayName').lean();
  if (!user) throw unauthorized();
  return user.displayName;
}

/**
 * "4BI - Software Eng." (class, then program) from the student's profile, as
 * the demo posts show it, or "Étudiant ESPRIT" when the school has not set
 * a profile yet (the default profile would be a guess).
 */
async function authorInfoOf(userId: string): Promise<string> {
  // Not lean: a hydrated document fills missing fields with their defaults.
  const profile = await StudentProfileModel.findOne({ userId });
  if (!profile) return UNKNOWN_CLASS_INFO;
  return `${profile.yearOfStudy}${profile.classGroup} - ${profile.programShort}`;
}

/**
 * Publishes an idea by [userId]. It starts with no votes and no comments;
 * the BDE sets a status later.
 */
export async function publishIdea(
  userId: string,
  { body, tag }: PublishIdeaInput,
): Promise<PublicForumPost> {
  const [authorName, authorInfo] = await Promise.all([
    displayNameOf(userId),
    authorInfoOf(userId),
  ]);
  const idea = await ForumPostModel.create({
    authorId: userId,
    authorName,
    authorInfo,
    category: 'idea',
    tag,
    body,
    place: null,
    upvotes: 0,
    comments: 0,
    status: null,
    postedAt: new Date(),
  });
  return toPublicPost(idea.toObject());
}

const isDuplicateKey = (err: unknown): boolean =>
  typeof err === 'object' && err !== null && (err as { code?: unknown }).code === 11000;

/**
 * Adds [userId]'s vote to [ideaId], or removes it if there is one. The unique
 * index keeps one vote per student and idea, even for two taps at once.
 */
export async function toggleIdeaUpvote(
  userId: string,
  ideaId: string,
): Promise<{ upvotes: number; isUpvotedByMe: boolean }> {
  const idea = await ForumPostModel.findOne({ _id: ideaId, category: 'idea' })
    .select('upvotes')
    .lean();
  if (!idea) throw notFound(IDEA_GONE);

  const removed = await IdeaVoteModel.deleteOne({ ideaId, userId });
  const isUpvotedByMe = removed.deletedCount === 0;
  if (isUpvotedByMe) {
    try {
      await IdeaVoteModel.create({ ideaId, userId });
    } catch (err) {
      // A simultaneous tap already voted: the student has one vote either way.
      if (!isDuplicateKey(err)) throw err;
    }
  }
  const votes = await IdeaVoteModel.countDocuments({ ideaId });
  return { upvotes: idea.upvotes + votes, isUpvotedByMe };
}

/** The whole Lost & Found board, newest first. Shared by every student. */
export async function listLostItems(): Promise<PublicLostItem[]> {
  const items = await LostItemModel.find().sort({ reportedAt: -1, _id: -1 }).lean();
  return items.map(toPublicLostItem);
}

/**
 * Publishes a lost or found notice by [userId]. The reporter, date and
 * reference are set here; a student's notice has no photo yet.
 */
export async function publishLostItem(
  userId: string,
  input: PublishLostItemInput,
): Promise<PublicLostItem> {
  const reporterName = await displayNameOf(userId);
  const item = await LostItemModel.create({
    kind: input.kind,
    title: input.title,
    category: input.category,
    zone: input.zone,
    location: input.location,
    place: input.place,
    distinctiveDetail: input.distinctiveDetail,
    reward: input.reward,
    isUrgent: input.isUrgent,
    dropOffNote: input.dropOffNote,
    pickupDesk: input.pickupDesk,
    reporterId: userId,
    reporterName,
    reporterIsStaff: false,
    reportedAt: new Date(),
    reference: await nextLostItemReference(),
    photoCount: 0,
    isSerialHidden: false,
  });
  return toPublicLostItem(item.toObject());
}

/**
 * Stores [userId]'s claim / "I found it" / serial check for [itemId]. A
 * student can send one request per item: the unique index makes a second
 * one (even two taps at once) fail, and we answer 409.
 */
export async function sendLostItemRequest(
  userId: string,
  itemId: string,
  proof: string,
): Promise<PublicLostItemRequest> {
  if (!(await LostItemModel.exists({ _id: itemId }))) throw notFound(ITEM_GONE);
  try {
    const request = await LostItemRequestModel.create({ itemId, userId, proof });
    return {
      id: request.id,
      itemId: request.itemId,
      proof: request.proof,
      createdAt: request.createdAt.toISOString(),
    };
  } catch (err) {
    if (isDuplicateKey(err)) throw conflict(ALREADY_SENT);
    throw err;
  }
}
