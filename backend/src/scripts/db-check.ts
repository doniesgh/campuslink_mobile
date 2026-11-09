import mongoose from 'mongoose';

import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';

/**
 * Checks the database address in MONGO_URL before giving it to Render:
 * connects, then writes and deletes one document. Says what is wrong in
 * plain words, and never prints the password.
 *
 *   npm run db:check
 *   (PowerShell, for Atlas:  $env:MONGO_URL = "mongodb+srv://..."; npm run db:check)
 */

/** The parts of [url] that are safe to show. */
function describe(url: string): { user: string; host: string; database: string } | null {
  const match = /^mongodb(?:\+srv)?:\/\/(?:([^:@/]*)(?::[^@/]*)?@)?([^/?]+)\/?([^?]*)/.exec(url);
  if (!match) return null;
  return {
    user: decodeURIComponent(match[1] ?? '') || '(none)',
    host: match[2] ?? '',
    database: match[3] || '(none)',
  };
}

const AUTH_HELP = [
  'The user name or the password is refused. Check, in Atlas > Database Access:',
  '  - The user name and password are exactly the ones in the address (case matters).',
  '  - No "<" or ">" is left around them: "<password>" is a placeholder to replace whole.',
  '  - A password with @ : / ? # [ ] % must be encoded. Print the encoded form with:',
  "      node -e \"console.log(encodeURIComponent('your password'))\"",
  '    or simpler: Edit the user > Edit Password > Autogenerate (letters and digits only).',
  '  - A new or edited user takes about a minute to be active.',
  '  - The user belongs to the project of this cluster.',
].join('\n');

function explain(err: unknown): string {
  const message = err instanceof Error ? err.message : String(err);
  const code = (err as { code?: unknown }).code;
  if (code === 18 || code === 8000 || /bad auth|authentication failed/i.test(message)) {
    return AUTH_HELP;
  }
  if (code === 13 || /not authorized/i.test(message)) {
    return 'Signed in, but this user may not write here: give it "readWrite" on this database (Atlas > Database Access > Edit > Specific Privileges).';
  }
  if (/ENOTFOUND|querySrv|ENODATA/i.test(message)) {
    return 'The cluster host is not found: check the part after "@" (copy the address again from Atlas > Connect > Drivers).';
  }
  if (/Server selection timed out|ETIMEDOUT|ECONNREFUSED/i.test(message)) {
    return 'The cluster does not answer: in Atlas > Network Access, allow 0.0.0.0/0 (needed for Render) or at least this PC.';
  }
  return message;
}

async function check(): Promise<void> {
  const url = env.MONGO_URL.trim();
  const parts = describe(url);
  if (!parts) {
    console.error('MONGO_URL does not look like a MongoDB address (mongodb+srv://user:password@host/database?...).');
    process.exitCode = 1;
    return;
  }
  console.info(`Host: ${parts.host} · database: ${parts.database} · user: ${parts.user}`);
  if (/[<>]/.test(url)) {
    console.error('The address still contains "<" or ">": replace each <placeholder>, brackets included.');
    process.exitCode = 1;
    return;
  }
  if (parts.database === '(none)') {
    console.warn('No database name: the data would go to "test". Add /campuspulse before the "?".');
  }

  try {
    await connectMongo(url);
    const collection = mongoose.connection.collection('dbcheck');
    const { insertedId } = await collection.insertOne({ checkedAt: new Date() });
    await collection.deleteOne({ _id: insertedId });
    await collection.drop().catch(() => undefined);
    console.info('OK: signed in, and this user can write to this database.');
  } catch (err) {
    console.error(`Failed: ${explain(err)}`);
    process.exitCode = 1;
  } finally {
    await disconnectMongo();
  }
}

void check();
