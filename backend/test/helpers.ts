import mongoose from 'mongoose';

import { connectMongo, disconnectMongo } from '../src/db/mongo';
import { setMailer } from '../src/modules/auth/mailer';

/** Connects to this worker's test database, empty, with the unique indexes built. */
export async function connectTestDb(): Promise<void> {
  await connectMongo(process.env.MONGO_URL as string);
  await mongoose.connection.dropDatabase();
  await Promise.all(Object.values(mongoose.models).map((m) => m.syncIndexes()));
}

/** Empties every collection but keeps the indexes. */
export async function clearTestDb(): Promise<void> {
  await Promise.all(
    Object.values(mongoose.connection.collections).map((c) => c.deleteMany({})),
  );
}

export async function closeTestDb(): Promise<void> {
  await mongoose.connection.dropDatabase();
  await disconnectMongo();
}

export interface SentMail {
  codes: { to: string; code: string }[];
  resets: { to: string; token: string }[];
}

/** Captures the auth emails instead of printing them. */
export function captureMail(): SentMail {
  const sent: SentMail = { codes: [], resets: [] };
  setMailer({
    async sendVerificationCode(to, code) {
      sent.codes.push({ to, code });
    },
    async sendPasswordReset(to, token) {
      sent.resets.push({ to, token });
    },
  });
  return sent;
}
