import type { Types } from 'mongoose';

import { unauthorized } from '../../lib/http-error';
import { UserModel } from '../users/user.model';
import type { AuditQuery } from './admin.schemas';
import { AuditLogModel, type AuditAction, type AuditLog } from './audit-log.model';
import { escapeRegex } from './search';

/** What the API sends for an audit entry. */
export interface AuditEntryJson {
  id: string;
  action: string;
  summary: string;
  actor: { id: string; displayName: string; email: string };
  targetId: string | null;
  metadata: Record<string, unknown>;
  ip: string | null;
  createdAt: string;
}

export interface AuditPage {
  items: AuditEntryJson[];
  total: number;
  page: number;
  limit: number;
}

type StoredAuditLog = AuditLog & { _id: Types.ObjectId; createdAt: Date };

export const toAuditEntryJson = (entry: StoredAuditLog): AuditEntryJson => ({
  id: entry._id.toHexString(),
  action: entry.action,
  summary: entry.summary,
  actor: {
    id: entry.actor.id,
    displayName: entry.actor.displayName,
    email: entry.actor.email,
  },
  targetId: entry.targetId ?? null,
  metadata: (entry.metadata as Record<string, unknown> | null) ?? {},
  ip: entry.ip ?? null,
  createdAt: entry.createdAt.toISOString(),
});

export interface AuditRecord {
  /** The admin who acted (their name and email are copied into the entry). */
  actorId: string;
  action: AuditAction;
  summary: string;
  targetId?: string | null;
  metadata?: Record<string, unknown>;
  ip: string | null;
}

/** Records one change made by an admin. Never put a password in [metadata]. */
export async function recordAudit(record: AuditRecord): Promise<void> {
  const actor = await UserModel.findById(record.actorId).select('displayName email');
  // The admin was checked by requireRole a moment ago: missing now means deleted meanwhile.
  if (!actor) throw unauthorized();
  await AuditLogModel.create({
    action: record.action,
    summary: record.summary,
    actor: { id: actor.id as string, displayName: actor.displayName, email: actor.email },
    targetId: record.targetId ?? null,
    metadata: record.metadata ?? {},
    ip: record.ip,
  });
}

/** `user.update` matches exactly; `user.*` matches every action starting with "user." (`*`: all). */
function actionFilter(action: string | undefined): Record<string, unknown> {
  if (!action) return {};
  if (action.endsWith('*')) {
    const prefix = action.slice(0, -1);
    return prefix ? { action: { $regex: `^${escapeRegex(prefix)}` } } : {};
  }
  return { action };
}

/** The audit log, newest first, one page at a time. */
export async function listAudit({ action, page, limit }: AuditQuery): Promise<AuditPage> {
  const filter = actionFilter(action);
  const [entries, total] = await Promise.all([
    AuditLogModel.find(filter)
      .sort({ createdAt: -1, _id: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .lean<StoredAuditLog[]>(),
    AuditLogModel.countDocuments(filter),
  ]);
  return { items: entries.map(toAuditEntryJson), total, page, limit };
}

/** The actions recorded so far, alphabetically (for the filter of the audit screen). */
export async function listAuditActions(): Promise<string[]> {
  const actions = await AuditLogModel.distinct('action');
  return (actions as string[]).sort((a, b) => a.localeCompare(b));
}
