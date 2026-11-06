import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';
import { sign, verify } from 'jsonwebtoken';

import { env } from '../../config/env';

/** Short-lived JWT carrying the user id (`sub`). */
export function signAccessToken(userId: string): string {
  return sign({}, env.JWT_ACCESS_SECRET, {
    subject: userId,
    expiresIn: env.ACCESS_TOKEN_TTL_SECONDS,
    algorithm: 'HS256',
  });
}

/** The user id of a valid access token, or null (expired, tampered, wrong secret...). */
export function verifyAccessToken(token: string): string | null {
  try {
    const payload = verify(token, env.JWT_ACCESS_SECRET, { algorithms: ['HS256'] });
    return typeof payload === 'object' && typeof payload.sub === 'string' ? payload.sub : null;
  } catch {
    return null;
  }
}

/** Opaque random token (refresh tokens, password reset links). */
export const randomToken = (bytes = 48): string => randomBytes(bytes).toString('base64url');

/** 6-digit email verification code, e.g. "042917". */
export const randomCode = (): string => randomInt(0, 1_000_000).toString().padStart(6, '0');

export const sha256 = (value: string): string => createHash('sha256').update(value).digest('hex');

/** Constant-time comparison of two hex hashes. */
export function hashesMatch(a: string, b: string): boolean {
  const left = Buffer.from(a, 'hex');
  const right = Buffer.from(b, 'hex');
  return left.length === right.length && timingSafeEqual(left, right);
}
