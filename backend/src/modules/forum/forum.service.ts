import { conflict, notFound } from '../../lib/http-error';
import { ForumPostModel, toPublicPost, type PublicForumPost } from './forum-post.model';
import { LostItemModel, toPublicLostItem, type PublicLostItem } from './lost-item.model';
import { LostItemRequestModel, type PublicLostItemRequest } from './lost-item-request.model';

/** Home shows a short strip of the latest posts, not the whole forum. */
export const HIGHLIGHTS_LIMIT = 10;

const ITEM_GONE = 'This item is no longer listed.';
const ALREADY_SENT =
  'You already sent a request for this item. The security desk will get back to you.';

/** Latest posts across all sections, newest first (Home "Campus Highlights"). */
export async function listHighlights(): Promise<PublicForumPost[]> {
  const posts = await ForumPostModel.find()
    .sort({ postedAt: -1, _id: -1 })
    .limit(HIGHLIGHTS_LIMIT)
    .lean();
  return posts.map(toPublicPost);
}

/** The whole Lost & Found board, newest first. Shared by every student. */
export async function listLostItems(): Promise<PublicLostItem[]> {
  const items = await LostItemModel.find().sort({ reportedAt: -1, _id: -1 }).lean();
  return items.map(toPublicLostItem);
}

const isDuplicateKey = (err: unknown): boolean =>
  typeof err === 'object' && err !== null && (err as { code?: unknown }).code === 11000;

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
