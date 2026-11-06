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
const VERIFICATION_TTL_MS = 15 * 60 * 1000;
const RESET_TTL_MS = 60 * 60 * 1000;
const MAX_VERIFICATION_ATTEMPTS = 5;

const INVALID_LOGIN = 'Invalid ENT ID/email or password.';
const SESSION_EXPIRED = 'Your session has expired. Please sign in again.';

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

/** Stores a fresh code on [user] (not saved) and returns it in clear for the email. */
function newVerificationCode(user: UserDocument): string {
  const code = randomCode();
  user.verificationCodeHash = sha256(code);
  user.verificationExpiresAt = new Date(Date.now() + VERIFICATION_TTL_MS);
  user.verificationAttempts = 0;
  return code;
}

export async function register(input: RegisterInput): Promise<Session> {
  if (await UserModel.exists({ email: input.email })) {
    throw conflict('An account with this email already exists.');
  }
  const user = new UserModel({
    email: input.email,
    displayName: input.displayName,
    passwordHash: await bcrypt.hash(input.password, BCRYPT_ROUNDS),
  });
  const code = newVerificationCode(user);
  await user.save();
  await mailer.sendVerificationCode(user.email, code);
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

/** Emails a reset token. Answers the same way whether the account exists or not. */
export async function forgotPassword(email: string): Promise<void> {
  const user = await UserModel.findOne({ email });
  if (!user) return;
  const token = randomToken(32);
  user.resetTokenHash = sha256(token);
  user.resetExpiresAt = new Date(Date.now() + RESET_TTL_MS);
  await user.save();
  await mailer.sendPasswordReset(user.email, token);
}

/** Sets a new password and signs the user out everywhere. */
export async function resetPassword({ token, password }: ResetPasswordInput): Promise<void> {
  const user = await UserModel.findOne({
    resetTokenHash: sha256(token),
    resetExpiresAt: { $gt: new Date() },
  });
  if (!user) throw badRequest('This reset link is invalid or has expired.');
  user.passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
  user.resetTokenHash = undefined;
  user.resetExpiresAt = undefined;
  await user.save();
  await revokeAllSessions(user._id);
}

export async function verifyEmail(userId: string, code: string): Promise<PublicUser> {
  const user = await UserModel.findById(userId).select(
    '+verificationCodeHash +verificationExpiresAt +verificationAttempts',
  );
  if (!user) throw unauthorized();
  if (user.isEmailVerified) return toPublicUser(user);

  const codeHash = user.verificationCodeHash;
  const expiresAt = user.verificationExpiresAt;
  const attempts = user.verificationAttempts ?? 0;
  if (!codeHash || !expiresAt || expiresAt <= new Date() || attempts >= MAX_VERIFICATION_ATTEMPTS) {
    throw badRequest('This code has expired. Request a new one.');
  }
  if (!hashesMatch(codeHash, sha256(code))) {
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
  const code = newVerificationCode(user);
  await user.save();
  await mailer.sendVerificationCode(user.email, code);
}
