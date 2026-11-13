import { conflict, forbidden, notFound, unauthorized, unprocessable } from '../../lib/http-error';
import type { Locale } from '../../lib/i18n';
import { VALIDATION_ERROR } from '../../lib/validate';
import { StudentProfileModel } from '../profile/profile.model';
import { localeOfUser, UserModel } from '../users/user.model';
import { nextLostItemReference } from './forum-counter.model';
import {
  ForumPostModel,
  toPublicPost,
  type ForumPost,
  type PublicForumPost,
} from './forum-post.model';
import {
  publishLostItemSchema,
  type PublishIdeaInput,
  type PublishLostItemInput,
  type UpdateLostItemInput,
} from './forum.schemas';
import { IdeaVoteModel } from './idea-vote.model';
import {
  LostItemModel,
  reporterIdOf,
  toPublicLostItem,
  type LostItem,
  type LostItemViewer,
  type PublicLostItem,
} from './lost-item.model';
import { LostItemRequestModel, type PublicLostItemRequest } from './lost-item-request.model';
import { aiVerdicts, MATCHING, ruleScore, type RuleScore } from './lost-item-matching';

/** Home shows a short strip of the latest posts, not the whole forum. */
export const HIGHLIGHTS_LIMIT = 10;

const ITEM_GONE = 'This item is no longer listed.';
const ALREADY_SENT =
  'You already sent a request for this item. The security desk will get back to you.';
const ITEM_RESOLVED = 'This item was already returned to its owner.';
const IDEA_GONE = "Cette idée n'existe plus.";
const NOTICE_GONE = "Cette annonce n'existe plus.";
const NOT_YOUR_NOTICE =
  "Seul l'auteur de l'annonce (ou un administrateur) peut la modifier ou la supprimer.";

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

/** Who is asking: decides `isMine` / `canManage`, and the language of the match reasons. */
type Viewer = LostItemViewer & { locale: Locale };

/** [userId] as a viewer of the board, or 401 for a valid token of a deleted account. */
async function viewerOf(userId: string): Promise<Viewer> {
  const user = await UserModel.findById(userId).select('role locale').lean();
  if (!user) throw unauthorized();
  return { userId, isAdmin: user.role === 'admin', locale: localeOfUser(user) };
}

/**
 * The whole Lost & Found board, newest first, resolved notices included.
 * Shared by every student; `isMine` / `canManage` are the viewer's.
 */
export async function listLostItems(userId: string): Promise<PublicLostItem[]> {
  const [viewer, items] = await Promise.all([
    viewerOf(userId),
    LostItemModel.find().sort({ reportedAt: -1, _id: -1 }).lean(),
  ]);
  return items.map((item) => toPublicLostItem(item, viewer));
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
  return toPublicLostItem(item.toObject(), { userId, isAdmin: false });
}

/** Notice [itemId], if [viewer] may manage it: 404 unknown, 403 neither its reporter nor an admin. */
async function managedNotice(viewer: Viewer, itemId: string) {
  const item = await LostItemModel.findById(itemId);
  if (!item) throw notFound(NOTICE_GONE);
  if (!viewer.isAdmin && reporterIdOf(item) !== viewer.userId) throw forbidden(NOT_YOUR_NOTICE);
  return item;
}

/**
 * Edits notice [itemId] (its reporter or an admin): the fields sent replace
 * the stored ones (null clears an optional field), then the notice is
 * checked whole, like a new one. Switching the kind drops the other kind's
 * fields. `status` marks it resolved (or active again).
 */
export async function updateLostItem(
  userId: string,
  itemId: string,
  input: UpdateLostItemInput,
): Promise<PublicLostItem> {
  const viewer = await viewerOf(userId);
  const item = await managedNotice(viewer, itemId);
  const { status, ...fields } = input;

  if (Object.keys(fields).length > 0) {
    const current = {
      kind: item.kind,
      title: item.title,
      category: item.category,
      zone: item.zone,
      location: item.location,
      place: item.place,
      distinctiveDetail: item.distinctiveDetail ?? null,
      reward: item.reward ?? null,
      isUrgent: item.isUrgent,
      dropOffNote: item.dropOffNote ?? null,
      pickupDesk: item.pickupDesk ?? null,
    };
    if (fields.kind === 'found' && item.kind === 'lost') {
      Object.assign(current, { reward: null, isUrgent: false });
    } else if (fields.kind === 'lost' && item.kind === 'found') {
      Object.assign(current, { dropOffNote: null, pickupDesk: null });
    }
    const edited = publishLostItemSchema.safeParse({ ...current, ...fields });
    if (!edited.success) {
      throw unprocessable(
        edited.error.issues[0]?.message ?? 'Invalid data.',
        undefined,
        VALIDATION_ERROR,
      );
    }
    item.set(edited.data);
  }
  if (status) item.status = status;
  await item.save();
  return toPublicLostItem(item.toObject(), viewer);
}

/** Deletes notice [itemId] (its reporter or an admin), with the requests sent about it. */
export async function deleteLostItem(userId: string, itemId: string): Promise<void> {
  const item = await managedNotice(await viewerOf(userId), itemId);
  await item.deleteOne();
  await LostItemRequestModel.deleteMany({ itemId });
}

export interface PublicLostItemMatch {
  item: PublicLostItem;
  /** 0-100. */
  score: number;
  /** The AI's reason, or the rule reasons joined ("Même catégorie · Même jour"). */
  reason: string;
  /** The rule reasons, in the viewer's language. */
  reasons: string[];
  /** The AI scored this match. */
  ai: boolean;
}

export interface PublicLostItemMatches {
  items: PublicLostItemMatch[];
  /** The AI re-ranked the matches (false: rules only). */
  ai: boolean;
  /** The model that answered, or null. */
  model: string | null;
}

const byNewest = (a: LostItem, b: LostItem) =>
  b.reportedAt.getTime() - a.reportedAt.getTime() || (a._id < b._id ? 1 : -1);

type ScoredItem = { item: LostItem; rule: RuleScore };

const ruleMatch = ({ item, rule }: ScoredItem) => ({
  item,
  score: rule.score,
  reason: rule.reasons.join(' · '),
  reasons: rule.reasons,
  ai: false,
});

/**
 * "Possible matches" of notice [itemId] (any signed-in user): active notices
 * of the opposite kind that may be the same object, best first (see
 * lost-item-matching.ts). A resolved notice has none. 404 unknown.
 */
export async function findLostItemMatches(
  userId: string,
  itemId: string,
): Promise<PublicLostItemMatches> {
  const viewer = await viewerOf(userId);
  const source = await LostItemModel.findById(itemId).lean();
  if (!source) throw notFound(NOTICE_GONE);
  if (source.status === 'resolved') return { items: [], ai: false, model: null };

  const pool = await LostItemModel.find({
    kind: source.kind === 'lost' ? 'found' : 'lost',
    _id: { $ne: source._id },
    status: { $ne: 'resolved' },
  })
    .sort({ reportedAt: -1, _id: -1 })
    .limit(MATCHING.poolSize)
    .lean();

  const scored: ScoredItem[] = [];
  for (const item of pool) {
    const rule = ruleScore(source, item, viewer.locale);
    if (rule) scored.push({ item, rule });
  }
  scored.sort((a, b) => b.rule.score - a.rule.score || byNewest(a.item, b.item));

  // The AI sees the best candidates by rules, and has the last word on them.
  const top = scored.slice(0, MATCHING.aiCandidates);
  const ai = await aiVerdicts(
    source,
    top.map((entry) => entry.item),
    viewer,
  );
  const matches = ai
    ? top.map((entry) => {
        const verdict = ai.verdicts.get(entry.item._id);
        if (!verdict) return ruleMatch(entry);
        return {
          ...ruleMatch(entry),
          score: Math.round(0.3 * entry.rule.score + 0.7 * verdict.score),
          reason: verdict.reason || ruleMatch(entry).reason,
          ai: true,
        };
      })
    : scored.map(ruleMatch);

  const items = matches
    .filter((match) => match.score >= MATCHING.minScore)
    .sort((a, b) => b.score - a.score || byNewest(a.item, b.item))
    .slice(0, MATCHING.maxResults)
    .map((match) => ({ ...match, item: toPublicLostItem(match.item, viewer) }));
  return { items, ai: ai !== null, model: ai?.model ?? null };
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
  const item = await LostItemModel.findById(itemId).select('status').lean();
  if (!item) throw notFound(ITEM_GONE);
  if (item.status === 'resolved') throw conflict(ITEM_RESOLVED);
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
