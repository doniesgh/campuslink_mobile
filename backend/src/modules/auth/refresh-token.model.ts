import { model, Schema } from 'mongoose';

/**
 * One refresh token per sign-in, stored as a SHA-256 hash (a leaked
 * database does not leak usable tokens). Rotated on every refresh: the old
 * one is revoked and a new one issued.
 */
const refreshTokenSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    tokenHash: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// MongoDB deletes expired tokens by itself.
refreshTokenSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const RefreshTokenModel = model('RefreshToken', refreshTokenSchema);
