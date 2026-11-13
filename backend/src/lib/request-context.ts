import type { Request, Response } from 'express';

import { currentUserId } from '../middleware/require-auth';

/** User-Agent headers longer than this are cut (they are only shown, never parsed). */
export const USER_AGENT_MAX_LENGTH = 512;

/** Where a request comes from: kept in the audit log next to who did what. */
export interface RequestMeta {
  /** The client IP ("::ffff:127.0.0.1" is given as "127.0.0.1"). Honours TRUST_PROXY. */
  ip: string | null;
  /** The User-Agent header, at most 512 characters (null when missing). */
  userAgent: string | null;
}

/** Who is acting, and from where. What `recordAudit` and the admin services take. */
export interface RequestContext extends RequestMeta {
  /** The signed-in user (an admin on the /admin routes). */
  actorId: string;
}

/** The client IP of [req], without the IPv4-mapped IPv6 prefix. */
export const clientIp = (req: Request): string | null =>
  req.ip?.replace(/^::ffff:/, '') ?? null;

/** The IP and User-Agent of [req], for a signed-out route (e.g. a password reset). */
export function requestMeta(req: Request): RequestMeta {
  const userAgent = req.get('user-agent')?.slice(0, USER_AGENT_MAX_LENGTH) || null;
  return { ip: clientIp(req), userAgent };
}

/** The signed-in user (set by requireAuth) with the request's IP and User-Agent. */
export const requestContext = (req: Request, res: Response): RequestContext => ({
  actorId: currentUserId(res),
  ...requestMeta(req),
});
