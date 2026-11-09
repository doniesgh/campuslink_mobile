import {
  toNotificationJson,
  type Notification,
  type NotificationJson,
} from '../notifications/notification.model';
import { PushDeviceModel } from './push-device.model';

/**
 * What a push tells the app (FCM data values must be strings). The app opens
 * the notification `notificationId` (the `id` of `GET /notifications`) and
 * goes to `destination` / `targetId` like a tap in the feed does.
 */
export type PushData = {
  notificationId: string;
  category: string;
  /** The link's destination, or "" when the notification has no link. */
  destination: string;
  /** The link's id (ride, job or user), or "". */
  targetId: string;
};

/** One FCM message to one phone (the subset of firebase-admin's `TokenMessage` used here). */
export interface PushMessage {
  token: string;
  notification: { title: string; body: string };
  data: PushData;
  /**
   * `tag`: a newer push of the same notification replaces the older one on
   * Android. `channelId`: the Android channel (created by the app), when not
   * the app's default one.
   */
  android: { priority: 'high'; notification: { tag: string; channelId?: string } };
  apns: { payload: { aps: { sound: string } } };
}

/** What a push shows, before it is addressed to a phone. */
export interface PushContent {
  title: string;
  /** Plain text. */
  body: string;
  data: PushData;
  tag: string;
  channelId?: string;
}

/** FCM's answer for one message: handed off, or refused with an error code. */
export type PushResult =
  | { ok: true }
  | { ok: false; code: string; message: string };

/** Delivers push messages. The real one is FCM (see fcm.ts); tests use a fake. */
export interface PushSender {
  /** Sends [messages] and answers one result per message, in the same order. */
  send(messages: PushMessage[]): Promise<PushResult[]>;
}

/** What one push run did. `devices` = `sent` + `failed` + `removed`. */
export interface PushReport {
  /** Phones the notifications went to (one message per phone and notification). */
  devices: number;
  sent: number;
  /** Refused for another reason (logged); the phone is kept. */
  failed: number;
  /** Phones FCM no longer knows (app uninstalled, token replaced): deleted. */
  removed: number;
}

/** The FCM answers that mean "this token will never work again". */
const DEAD_TOKEN_CODES: ReadonlySet<string> = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** Null while push is off (no FIREBASE_SERVICE_ACCOUNT_FILE, and in tests by default). */
let sender: PushSender | null = null;

/** Turns push on with [next], or off with null. Called by `initPush` (fcm.ts) and the tests. */
export function setPushSender(next: PushSender | null): void {
  sender = next;
}

export const isPushOn = (): boolean => sender !== null;

const noPush = (): PushReport => ({ devices: 0, sent: 0, failed: 0, removed: 0 });

// The light markup of notification bodies, matched like the app does
// (lib/features/notifications/presentation/widgets/rich_body_text.dart).
const MARKUP = /\*\*(.+?)\*\*|~~(.+?)~~|==(.+?)==/g;

/** [body] without its markup: "**10:15** in ==Amphi C==" becomes "10:15 in Amphi C". */
export function plainText(body: string): string {
  return body.replace(
    MARKUP,
    (_match, strong?: string, struck?: string, highlight?: string) =>
      strong ?? struck ?? highlight ?? '',
  );
}

/** The FCM message that shows [content] on the phone [token]. */
function toMessage(content: PushContent, token: string): PushMessage {
  const { title, body, data, tag, channelId } = content;
  return {
    token,
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: channelId === undefined ? { tag } : { tag, channelId },
    },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

/** The FCM message that shows [notification] on the phone [token]. */
export function toPushMessage(notification: NotificationJson, token: string): PushMessage {
  return toMessage(
    {
      title: notification.title,
      body: plainText(notification.body),
      data: {
        notificationId: notification.id,
        category: notification.category,
        destination: notification.link?.destination ?? '',
        targetId: notification.link?.id ?? '',
      },
      tag: notification.id,
    },
    token,
  );
}

/** One message per notification and phone of its user. */
async function messagesFor(notifications: readonly Notification[]): Promise<PushMessage[]> {
  const userIds = [...new Set(notifications.map((n) => n.userId.toString()))];
  const devices = await PushDeviceModel.find({ userId: { $in: userIds } })
    .select('userId token')
    .lean();
  const tokensByUser = new Map<string, string[]>();
  for (const { userId, token } of devices) {
    const key = userId.toString();
    tokensByUser.set(key, [...(tokensByUser.get(key) ?? []), token]);
  }
  return notifications.flatMap((notification) => {
    const json = toNotificationJson(notification);
    const tokens = tokensByUser.get(notification.userId.toString()) ?? [];
    return tokens.map((token) => toPushMessage(json, token));
  });
}

/** Sends [messages], deletes the dead tokens and reports. Never throws (errors are logged). */
async function deliver(current: PushSender, messages: PushMessage[]): Promise<PushReport> {
  const report: PushReport = { ...noPush(), devices: messages.length };
  if (messages.length === 0) return report;
  try {
    const results = await current.send(messages);
    const deadTokens = new Set<string>();
    // Per error code: how many times, and FCM's explanation (the first one).
    const errors = new Map<string, { count: number; message: string }>();
    messages.forEach((message, i) => {
      const result = results[i] ?? { ok: false, code: 'no-answer', message: 'No answer from FCM.' };
      if (result.ok) {
        report.sent += 1;
      } else if (DEAD_TOKEN_CODES.has(result.code)) {
        deadTokens.add(message.token);
      } else {
        report.failed += 1;
        const seen = errors.get(result.code);
        errors.set(result.code, { count: (seen?.count ?? 0) + 1, message: seen?.message ?? result.message });
      }
    });
    if (errors.size > 0) {
      const summary = [...errors]
        .map(([code, { count, message }]) => `${code} (${count}): ${message}`)
        .join(' | ');
      console.error(`[push] ${report.failed} of ${report.devices} push message(s) failed: ${summary}`);
    }
    if (deadTokens.size > 0) {
      const { deletedCount } = await PushDeviceModel.deleteMany({ token: { $in: [...deadTokens] } });
      report.removed = deletedCount;
    }
  } catch (err) {
    console.error('[push] Could not send push notifications:', err);
    report.failed = report.devices - report.sent - report.removed;
  }
  return report;
}

/**
 * Pushes [notifications] to every phone of their users and waits for FCM's
 * answers (used by `npm run push:test`). Never throws. When push is off,
 * nothing is read or sent and the report is all zeros.
 */
export async function pushNotifications(
  notifications: readonly Notification[],
): Promise<PushReport> {
  const current = sender;
  if (!current || notifications.length === 0) return noPush();
  try {
    return await deliver(current, await messagesFor(notifications));
  } catch (err) {
    console.error('[push] Could not find the phones to notify:', err);
    return noPush();
  }
}

/**
 * Pushes [content], which is not one of the users' notifications (a class
 * reminder: nothing to keep in the feed), to every phone of [userIds], and
 * waits for FCM's answers. Never throws. Does nothing when push is off.
 */
export async function pushToUsers(
  userIds: readonly string[],
  content: PushContent,
): Promise<PushReport> {
  const current = sender;
  if (!current || userIds.length === 0) return noPush();
  try {
    const devices = await PushDeviceModel.find({ userId: { $in: userIds } })
      .select('token')
      .lean();
    return await deliver(
      current,
      devices.map(({ token }) => toMessage(content, token)),
    );
  } catch (err) {
    console.error('[push] Could not find the phones to notify:', err);
    return noPush();
  }
}

/** The background sends not answered yet (see [settlePushes]). */
const pending = new Set<Promise<PushReport>>();

/**
 * Pushes [notifications] without making the caller wait for FCM: it only
 * waits for the list of phones (one indexed read), then sends in the
 * background. Reading the phones first means a sign-out that follows at once
 * (an admin's password change removes the phones) still gets its push out.
 * Never rejects: problems are logged. Does nothing when push is off.
 *
 * Tests wait for the background sends with [settlePushes].
 */
export async function pushInBackground(notifications: readonly Notification[]): Promise<void> {
  const current = sender;
  if (!current || notifications.length === 0) return;
  let messages: PushMessage[];
  try {
    messages = await messagesFor(notifications);
  } catch (err) {
    console.error('[push] Could not find the phones to notify:', err);
    return;
  }
  if (messages.length === 0) return;
  const task: Promise<PushReport> = deliver(current, messages).finally(() => {
    pending.delete(task);
  });
  pending.add(task);
}

/** Resolves once every push started by [pushInBackground] has been answered. */
export async function settlePushes(): Promise<void> {
  // Again until none is left: a push may start while the others are waited for.
  while (pending.size > 0) await Promise.allSettled(pending);
}
