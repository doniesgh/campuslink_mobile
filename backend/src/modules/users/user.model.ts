import { model, Schema, type HydratedDocument, type InferSchemaType } from 'mongoose';

const userSchema = new Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },

    /** ENT identifier (e.g. 211JMT0428), assigned by the school. Optional at sign-up. */
    studentId: { type: String, unique: true, sparse: true, uppercase: true, trim: true },

    displayName: { type: String, required: true, trim: true },
    avatarUrl: { type: String, default: null },
    isEmailVerified: { type: Boolean, default: false },

    // Secrets: never returned unless explicitly selected (.select('+field')).
    passwordHash: { type: String, required: true, select: false },
    verificationCodeHash: { type: String, select: false },
    verificationExpiresAt: { type: Date, select: false },
    verificationAttempts: { type: Number, default: 0, select: false },
    resetTokenHash: { type: String, select: false, index: { sparse: true } },
    resetExpiresAt: { type: Date, select: false },
  },
  { timestamps: true },
);

export type User = InferSchemaType<typeof userSchema>;
export type UserDocument = HydratedDocument<User>;

export const UserModel = model('User', userSchema);

/** What the API sends for a user (the shape the app's UserModel.fromJson reads). */
export interface PublicUser {
  id: string;
  email: string;
  studentId: string | null;
  displayName: string;
  avatarUrl: string | null;
  isEmailVerified: boolean;
}

export const toPublicUser = (user: UserDocument): PublicUser => ({
  id: user.id,
  email: user.email,
  studentId: user.studentId ?? null,
  displayName: user.displayName,
  avatarUrl: user.avatarUrl ?? null,
  isEmailVerified: user.isEmailVerified,
});
