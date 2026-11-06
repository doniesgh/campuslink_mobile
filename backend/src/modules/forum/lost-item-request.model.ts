import { model, Schema, type InferSchemaType } from 'mongoose';

/**
 * A student's request about a Lost & Found item ("C'est à moi", "J'ai trouvé
 * cet objet", serial-number check), sent to the campus security desk.
 * `createdAt` is when it was sent.
 */
const lostItemRequestSchema = new Schema(
  {
    itemId: { type: String, ref: 'LostItem', required: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },

    /** The distinctive detail typed by the student. */
    proof: { type: String, required: true, trim: true },
  },
  { timestamps: true },
);

// One request per student and item: a second one is refused (409).
lostItemRequestSchema.index({ itemId: 1, userId: 1 }, { unique: true });

export type LostItemRequest = InferSchemaType<typeof lostItemRequestSchema>;

export const LostItemRequestModel = model('LostItemRequest', lostItemRequestSchema);

/** What the API sends back once a request is stored. */
export interface PublicLostItemRequest {
  id: string;
  itemId: string;
  proof: string;
  createdAt: string;
}
