import { model, Schema } from 'mongoose';

/** Named sequences of the forum (one document per sequence). */
const forumCounterSchema = new Schema(
  {
    _id: { type: String, required: true },
    seq: { type: Number, required: true },
  },
  { versionKey: false },
);

export const ForumCounterModel = model('ForumCounter', forumCounterSchema);

/**
 * Number of the first notice published from the app: the demo board ends at
 * "lf-411", so published notices continue with "LF-412", "LF-413"...
 */
export const FIRST_LOST_ITEM_REFERENCE = 412;

/**
 * The next Lost & Found reference ("LF-412"). The increment is atomic, so two
 * notices published at once never get the same reference.
 */
export async function nextLostItemReference(): Promise<string> {
  const counter = await ForumCounterModel.findOneAndUpdate(
    { _id: 'lostItemReference' },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' },
  ).lean();
  const seq = counter?.seq ?? 1;
  return `LF-${FIRST_LOST_ITEM_REFERENCE - 1 + seq}`;
}
