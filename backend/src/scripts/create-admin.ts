import { z } from 'zod';

import { env } from '../config/env';
import { connectMongo, disconnectMongo } from '../db/mongo';
import { hashPassword, revokeAllSessions } from '../modules/auth/auth.service';
import { backfillRoles, UserModel } from '../modules/users/user.model';

/**
 * Creates the first admin of a real server, or promotes an existing account:
 *
 *   npm run create-admin -- <email> <password> [display name]
 *
 * An existing account becomes an admin with the new password (verified),
 * and is signed out on every device. There are no default credentials.
 */
const USAGE = 'Usage: npm run create-admin -- <email> <password> [display name]';
const DEFAULT_NAME = 'Campus Admin';

const argsSchema = z.object({
  email: z.string().trim().toLowerCase().pipe(z.email('Not a valid email address.')),
  password: z
    .string()
    .min(8, 'The password needs at least 8 characters.')
    .max(128, 'The password can have at most 128 characters.'),
  displayName: z.string().trim().max(80, 'The display name can have at most 80 characters.'),
});

async function createAdmin(args: z.output<typeof argsSchema>): Promise<void> {
  await connectMongo(env.MONGO_URL);
  await backfillRoles();
  const passwordHash = await hashPassword(args.password);

  const existing = await UserModel.findOne({ email: args.email });
  if (existing) {
    existing.role = 'admin';
    existing.passwordHash = passwordHash;
    existing.isEmailVerified = true;
    if (args.displayName) existing.displayName = args.displayName;
    await existing.save();
    await revokeAllSessions(existing._id);
    console.info(`${existing.email} (${existing.displayName}) is now an admin.`);
    console.info('Its password was changed and every session was signed out.');
    return;
  }

  const admin = await UserModel.create({
    email: args.email,
    displayName: args.displayName || DEFAULT_NAME,
    role: 'admin',
    isEmailVerified: true,
    passwordHash,
  });
  console.info(`Created the admin ${admin.email} (${admin.displayName}).`);
}

function main(): void {
  const [email, password, ...nameParts] = process.argv.slice(2);
  if (!email || !password) {
    console.error(USAGE);
    process.exitCode = 1;
    return;
  }
  const args = argsSchema.safeParse({ email, password, displayName: nameParts.join(' ') });
  if (!args.success) {
    console.error(args.error.issues.map((issue) => issue.message).join('\n'));
    console.error(USAGE);
    process.exitCode = 1;
    return;
  }

  createAdmin(args.data)
    .catch((err: unknown) => {
      console.error('Could not create the admin:', err);
      process.exitCode = 1;
    })
    .finally(() => disconnectMongo());
}

main();
