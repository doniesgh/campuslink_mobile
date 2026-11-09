import { model, Schema, type InferSchemaType } from 'mongoose';

/** The phones the app runs on. Sent as-is by the app. */
export const PUSH_PLATFORMS = ['android', 'ios'] as const;
export type PushPlatform = (typeof PUSH_PLATFORMS)[number];

/**
 * A phone that receives the push notifications of one account. The app
 * registers its Firebase Cloud Messaging token after every sign-in. One token
 * belongs to one account at a time: the last account signed in on the phone.
 */
const pushDeviceSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    /** The FCM registration token of the app on this phone. */
    token: { type: String, required: true, unique: true },
    platform: { type: String, enum: PUSH_PLATFORMS, required: true },
    /** The last time the app registered this token (each sign-in, each new token). */
    lastSeenAt: { type: Date, required: true, default: Date.now },
  },
  { timestamps: true },
);

export type PushDevice = InferSchemaType<typeof pushDeviceSchema>;

export const PushDeviceModel = model('PushDevice', pushDeviceSchema);
