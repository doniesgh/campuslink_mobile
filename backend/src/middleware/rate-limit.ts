import { isIPv4 } from 'node:net';

import type { Request, RequestHandler, Response } from 'express';
import { ipKeyGenerator, MemoryStore, rateLimit } from 'express-rate-limit';

import { isProd, isTest } from '../config/env';
import { tooManyRequests } from '../lib/http-error';

/*
 * Rate limits. Every limiter answers
 *   429 { message, code: 'TOO_MANY_REQUESTS', retryAfter }   (retryAfter in seconds)
 * with a `Retry-After` header. Counters are in memory (one set per API
 * instance, reset by a restart).
 *
 *   createLimiter({ name, limit, windowMs, key })  the factory: one counter per key
 *   authLimit(name)       one auth route, per route + IP + normalised email / identifier
 *   authIpLimit           every signed-out auth route together, per IP (not for loopback)
 *   userLimit({ name, limit, windowMs })  one action of the signed-in user (after requireAuth)
 *
 * Limits are off under NODE_ENV=test, so tests can call a route many times. A
 * test of a limit turns them on with `enforceRateLimitsInTests()`.
 */

const MINUTE_MS = 60 * 1000;
/** The window of the auth limits. */
export const AUTH_WINDOW_MS = 15 * MINUTE_MS;

/** Outside production the auth limits are 5 times higher, so local testing is never blocked. */
const scaled = (limit: number) => (isProd ? limit : limit * 5);

/** What a limiter counts a request as: a string, or null for "don't count this one". */
export type LimiterKey = (req: Request, res: Response) => string | null;

export interface LimiterOptions {
  /** Names the counters (part of every key) and the `RateLimit` headers, e.g. "login". */
  name: string;
  /** Requests allowed per window and key. */
  limit: number;
  windowMs: number;
  /** One counter per key. Return null to let a request through without counting it. */
  key: LimiterKey;
  /** The message of the 429 answer (shown as-is in the app). */
  message?: string;
}

export const DEFAULT_LIMIT_MESSAGE = 'Too many attempts. Try again in a few minutes.';

/** Every limiter's counters, so tests can start from zero. */
const stores: MemoryStore[] = [];
let enforcedInTests = false;

/** Tests: turn the limits on (true) or off again (false). Either way, every counter restarts from zero. */
export function enforceRateLimitsInTests(on = true): void {
  enforcedInTests = on;
  resetRateLimits();
}

/** Empties every counter (tests). */
export function resetRateLimits(): void {
  for (const store of stores) void store.resetAll();
}

/**
 * A limiter middleware: at most [limit] requests per [windowMs] for each key
 * that [key] gives (prefixed with [name]). Mount it before `validateBody`
 * when the key reads the body: it sees the body as sent.
 */
export function createLimiter({
  name,
  limit,
  windowMs,
  key,
  message = DEFAULT_LIMIT_MESSAGE,
}: LimiterOptions): RequestHandler {
  const store = new MemoryStore();
  stores.push(store);
  return rateLimit({
    windowMs,
    limit,
    store,
    identifier: name,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    skip: (req, res) => (isTest && !enforcedInTests) || key(req, res) === null,
    keyGenerator: (req, res) => `${name}|${key(req, res) ?? ''}`,
    handler: (req, res, next) => {
      const resetTime = (req as Request & { rateLimit?: { resetTime?: Date } }).rateLimit
        ?.resetTime;
      const retryAfter = resetTime
        ? Math.max(1, Math.ceil((resetTime.getTime() - Date.now()) / 1000))
        : Math.ceil(windowMs / 1000);
      res.set('Retry-After', String(retryAfter));
      next(tooManyRequests(message, retryAfter));
    },
  });
}

/** The client IP for a counter (IPv6 addresses grouped by /56, as express-rate-limit advises). */
export const limiterIp = (req: Request): string => ipKeyGenerator(req.ip ?? '');

/** True for 127.0.0.0/8, ::1 and IPv4-mapped loopback (::ffff:127.x.x.x). */
export function isLoopback(ip: string | undefined): boolean {
  const value = (ip ?? '').trim().toLowerCase();
  if (value === '::1' || value === '0:0:0:0:0:0:0:1') return true;
  const v4 = value.startsWith('::ffff:') ? value.slice('::ffff:'.length) : value;
  return isIPv4(v4) && v4.startsWith('127.');
}

/** The email (or ENT ID / email `identifier` of login) of a signed-out auth request, normalised. */
function identifierOf(req: Request): string {
  const body = (req.body ?? {}) as { email?: unknown; identifier?: unknown };
  const value = typeof body.email === 'string' ? body.email : body.identifier;
  return typeof value === 'string' ? value.trim().toLowerCase().slice(0, 320) : '';
}

/**
 * One signed-out auth route (login, register, forgot-password...): one
 * counter per route, IP and email / identifier, so students behind the same
 * campus network don't block each other. 20 tries per 15 minutes in
 * production (100 elsewhere).
 */
export const authLimit = (name: string): RequestHandler =>
  createLimiter({
    name: `auth:${name}`,
    limit: scaled(20),
    windowMs: AUTH_WINDOW_MS,
    key: (req) => `${limiterIp(req)}|${identifierOf(req)}`,
  });

/**
 * Every signed-out auth route together, one counter per IP (password
 * guessing over many accounts): 100 requests per 15 minutes in production
 * (500 elsewhere). Not applied to a loopback IP, i.e. a caller on this
 * machine (the emulator through `adb reverse`, a dev on localhost): behind
 * a proxy (Render, TRUST_PROXY=1) the IP is the real client's.
 */
export const authIpLimit: RequestHandler = createLimiter({
  name: 'auth-ip',
  limit: scaled(100),
  windowMs: AUTH_WINDOW_MS,
  key: (req) => (isLoopback(req.ip) ? null : limiterIp(req)),
});

/**
 * One action of the signed-in user (mount it after requireAuth): one counter
 * per user, so users behind the same network never share a budget. Falls
 * back to the IP without a signed-in user.
 *
 * `userLimit({ name: 'offer-summary', limit: 30, windowMs: 60 * 60 * 1000 })`
 */
export const userLimit = (options: {
  name: string;
  limit: number;
  windowMs: number;
  message?: string;
}): RequestHandler =>
  createLimiter({
    ...options,
    key: (req, res) => {
      const userId = res.locals.userId as string | undefined;
      return userId ? `user:${userId}` : `ip:${limiterIp(req)}`;
    },
  });
