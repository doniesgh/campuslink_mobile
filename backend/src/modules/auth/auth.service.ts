import bcrypt from 'bcryptjs';
import type { Types } from 'mongoose';

import { env } from '../../config/env';
import { badRequest, conflict, unauthorized } from '../../lib/http-error';
import { toPublicUser, UserModel, type PublicUser, type UserDocument } from '../users/user.model';
import type { LoginInput, RegisterInput, ResetPasswordInput } from './auth.schemas';
import { mailer } from './mailer';
import { RefreshTokenModel } from './refresh-token.model';
import { hashesMatch, randomCode, randomToken, sha256, signAccessToken } from './tokens';

const BCRYPT_ROUNDS = 10;
const DAY_MS = 24 * 60 * 60 * 1000;
const CODE_TTL_MS = 15 * 60 * 1000;
const MAX_CODE_ATTEMPTS = 5;

const INVALID_LOGIN = 'Invalid ENT ID/email or password.';
const SESSION_EXPIRED = 'Your session has expired. Please sign in again.';
// One message for every reset failure, so the endpoint can't reveal who has an account.
const INVALID_RESET = 'Invalid or expired code. Check the email or request a new code.';

// Checked when the account does not exist, so an unknown identifier takes as
// long as a wrong password (no account discovery by timing).
const DUMMY_HASH = bcrypt.hashSync('campuspulse-dummy-password', BCRYPT_ROUNDS);

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

/** Login / register response: `{ user, accessToken, refreshToken }`. */
export interface Session extends TokenPair {
  user: PublicUser;
}

async function issueTokens(userId: Types.ObjectId): Promise<TokenPair> {
  const refreshToken = randomToken();
  await RefreshTokenModel.create({
    userId,
    tokenHash: sha256(refreshToken),
    expiresAt: new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * DAY_MS),
  });
  return { accessToken: signAccessToken(userId.toString()), refreshToken };
}

async function startSession(user: UserDocument): Promise<Session> {
  return { user: toPublicUser(user), ...(await issueTokens(user._id)) };
}

async function revokeAllSessions(userId: Types.ObjectId): Promise<void> {
  await RefreshTokenModel.updateMany(
    { userId, revokedAt: null },
    { $set: { revokedAt: new Date() } },
  );
}

/**
 * Sends an email without letting a mail-server problem break the request:
 * the account change is already saved and the student can ask for a new code.
 */
async function sendSafely(send: () => Promise<void>): Promise<void> {
  try {
    await send();
  } catch (err) {
    console.error('[mail] Could not send an email:', err);
  }
}

/** A fresh 6-digit code: its hash and expiry to store, and the code in clear for the email. */
function newCode(): { code: string; hash: string; expiresAt: Date } {
  const code = randomCode();
  return { code, hash: sha256(code), expiresAt: new Date(Date.now() + CODE_TTL_MS) };
}

type CodeCheck = 'ok' | 'expired' | 'wrong';

/** Checks [code] against a stored (hash, expiry, attempts) triple. */
function checkCode(
  hash: string | null | undefined,
  expiresAt: Date | null | undefined,
  attempts: number,
  code: string,
): CodeCheck {
  if (!hash || !expiresAt || expiresAt <= new Date() || attempts >= MAX_CODE_ATTEMPTS) {
    return 'expired';
  }
  return hashesMatch(hash, sha256(code)) ? 'ok' : 'wrong';
}

export async function register(input: RegisterInput): Promise<Session> {
  if (await UserModel.exists({ email: input.email })) {
    throw conflict('An account with this email already exists.');
  }
  const { code, hash, expiresAt } = newCode();
  const user = await UserModel.create({
    email: input.email,
    displayName: input.displayName,
    passwordHash: await bcrypt.hash(input.password, BCRYPT_ROUNDS),
    verificationCodeHash: hash,
    verificationExpiresAt: expiresAt,
    verificationAttempts: 0,
  });
  await sendSafely(() => mailer.sendVerificationCode(user.email, code));
  return startSession(user);
}

/** [identifier] is an email (contains "@") or an ENT ID such as 211JMT0428. */
export async function login({ identifier, password }: LoginInput): Promise<Session> {
  const query = identifier.includes('@')
    ? { email: identifier.toLowerCase() }
    : { studentId: identifier.toUpperCase() };
  const user = await UserModel.findOne(query).select('+passwordHash');
  const passwordOk = await bcrypt.compare(password, user?.passwordHash ?? DUMMY_HASH);
  if (!user || !passwordOk) throw unauthorized(INVALID_LOGIN);
  return startSession(user);
}

/**
 * Exchanges a refresh token for a new pair. The old token is revoked; if a
 * revoked token is presented again it was probably stolen, so every session
 * of that user is ended.
 */
export async function refresh(refreshToken: string): Promise<TokenPair> {
  const tokenHash = sha256(refreshToken);
  const now = new Date();
  // Atomic: of two requests racing with the same token, only one wins.
  const current = await RefreshTokenModel.findOneAndUpdate(
    { tokenHash, revokedAt: null, expiresAt: { $gt: now } },
    { $set: { revokedAt: now } },
  );
  if (!current) {
    const reused = await RefreshTokenModel.findOne({ tokenHash, revokedAt: { $ne: null } });
    if (reused) await revokeAllSessions(reused.userId);
    throw unauthorized(SESSION_EXPIRED);
  }
  if (!(await UserModel.exists({ _id: current.userId }))) throw unauthorized(SESSION_EXPIRED);
  return issueTokens(current.userId);
}

/** Ends one session (the device signing out). Unknown tokens are ignored. */
export async function logout(refreshToken: string): Promise<void> {
  await RefreshTokenModel.updateOne(
    { tokenHash: sha256(refreshToken), revokedAt: null },
    { $set: { revokedAt: new Date() } },
  );
}

/** Emails a 6-digit reset code. Answers the same way whether the account exists or not. */
export async function forgotPassword(email: string): Promise<void> {
  const user = await UserModel.findOne({ email });
  if (!user) return;
  const { code, hash, expiresAt } = newCode();
  user.resetCodeHash = hash;
  user.resetExpiresAt = expiresAt;
  user.resetAttempts = 0;
  await user.save();
  await sendSafely(() => mailer.sendPasswordResetCode(user.email, code));
}

/** Sets a new password with the emailed code, then signs the user out everywhere. */
export async function resetPassword({ email, code, password }: ResetPasswordInput): Promise<void> {
  const user = await UserModel.findOne({ email }).select(
    '+resetCodeHash +resetExpiresAt +resetAttempts',
  );
  if (!user) throw badRequest(INVALID_RESET);

  const attempts = user.resetAttempts ?? 0;
  const check = checkCode(user.resetCodeHash, user.resetExpiresAt, attempts, code);
  if (check !== 'ok') {
    if (check === 'wrong') {
      user.resetAttempts = attempts + 1;
      await user.save();
    }
    throw badRequest(INVALID_RESET);
  }

  user.passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  user.resetCodeHash = undefined;
  user.resetExpiresAt = undefined;
  user.resetAttempts = 0;
  await user.save();
  await revokeAllSessions(user._id);
}

export async function verifyEmail(userId: string, code: string): Promise<PublicUser> {
  const user = await UserModel.findById(userId).select(
    '+verificationCodeHash +verificationExpiresAt +verificationAttempts',
  );
  if (!user) throw unauthorized();
  if (user.isEmailVerified) return toPublicUser(user);

  const attempts = user.verificationAttempts ?? 0;
  const check = checkCode(user.verificationCodeHash, user.verificationExpiresAt, attempts, code);
  if (check === 'expired') throw badRequest('This code has expired. Request a new one.');
  if (check === 'wrong') {
    user.verificationAttempts = attempts + 1;
    await user.save();
    throw badRequest('Invalid code. Check the email we sent you.');
  }

  user.isEmailVerified = true;
  user.verificationCodeHash = undefined;
  user.verificationExpiresAt = undefined;
  user.verificationAttempts = 0;
  await user.save();
  return toPublicUser(user);
}

export async function resendVerification(userId: string): Promise<void> {
  const user = await UserModel.findById(userId);
  if (!user) throw unauthorized();
  if (user.isEmailVerified) return;
  const { code, hash, expiresAt } = newCode();
  user.verificationCodeHash = hash;
  user.verificationExpiresAt = expiresAt;
  user.verificationAttempts = 0;
  await user.save();
  await sendSafely(() => mailer.sendVerificationCode(user.email, code));
}
