import { readFileSync } from 'node:fs';
import path from 'node:path';

// Types only: erased at build time. firebase-admin itself is loaded by
// [initPush], and only when push is configured (never in the tests).
import type { App } from 'firebase-admin/app';
import type { Messaging } from 'firebase-admin/messaging';

import { env, isTest } from '../../config/env';
import { setPushSender, type PushResult, type PushSender } from './push.service';

/** backend/, where relative FIREBASE_SERVICE_ACCOUNT_FILE paths start (from src/ and dist/ alike). */
const BACKEND_DIR = path.resolve(__dirname, '..', '..', '..');

/** FCM takes at most 500 messages per `sendEach` call. */
const FCM_BATCH_SIZE = 500;

const FIREBASE_APP_NAME = 'campuspulse-push';

const KEY_HELP =
  'Download a key from the Firebase console: Project settings > Service accounts > ' +
  'Generate new private key.';

/** The fields of a service account key file used here. */
interface ServiceAccountKey {
  project_id: string;
  client_email: string;
  private_key: string;
}

let firebaseApp: App | null = null;

/** A [PushSender] over firebase-admin's Messaging (FCM HTTP v1). */
export function createFcmSender(messaging: Pick<Messaging, 'sendEach'>): PushSender {
  return {
    async send(messages) {
      const results: PushResult[] = [];
      for (let start = 0; start < messages.length; start += FCM_BATCH_SIZE) {
        const batch = await messaging.sendEach(messages.slice(start, start + FCM_BATCH_SIZE));
        for (const response of batch.responses) {
          results.push(
            response.success
              ? { ok: true }
              : {
                  ok: false,
                  code: response.error?.code ?? 'unknown',
                  message: response.error?.message ?? '',
                },
          );
        }
      }
      return results;
    },
  };
}

/** The key in [file], or what is wrong with it (a sentence for the console). */
function readServiceAccountKey(file: string): ServiceAccountKey | string {
  let text: string;
  try {
    text = readFileSync(file, 'utf8');
  } catch {
    return `cannot read ${file}. Check FIREBASE_SERVICE_ACCOUNT_FILE (relative paths start in backend/).`;
  }
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    return `${file} is not valid JSON. ${KEY_HELP}`;
  }
  if (typeof json !== 'object' || json === null) return `${file} is not a service account key. ${KEY_HELP}`;
  const key = json as Record<string, unknown>;
  if ('project_info' in key) {
    return `${file} is the app's google-services.json, not a service account key. ${KEY_HELP}`;
  }
  const missing = ['project_id', 'client_email', 'private_key'].filter(
    (field) => typeof key[field] !== 'string' || key[field] === '',
  );
  if (missing.length > 0) {
    return `${file} is not a service account key (no ${missing.join(', ')}). ${KEY_HELP}`;
  }
  return key as unknown as ServiceAccountKey;
}

/**
 * Turns push notifications on when FIREBASE_SERVICE_ACCOUNT_FILE names a
 * Firebase service account key: loads firebase-admin (only then) and sends
 * through FCM. Called once at start-up. Never throws: without the variable,
 * or with an unusable key, push stays off and the console says why.
 * Returns whether push is on.
 */
export async function initPush(file = env.FIREBASE_SERVICE_ACCOUNT_FILE): Promise<boolean> {
  if (firebaseApp) return true;
  if (!file) {
    console.info('[push] Off: set FIREBASE_SERVICE_ACCOUNT_FILE to send push notifications.');
    return false;
  }
  const keyFile = path.resolve(BACKEND_DIR, file);
  const key = readServiceAccountKey(keyFile);
  if (typeof key === 'string') {
    console.error(`[push] Off: ${key}`);
    return false;
  }
  if (isTest) {
    // firebase-admin is loaded with import(), which Jest's sandbox can't run.
    console.error('[push] Off: the tests never load firebase-admin (use capturePush).');
    return false;
  }

  try {
    const { cert, initializeApp } = await import('firebase-admin/app');
    const { getMessaging } = await import('firebase-admin/messaging');
    const app = initializeApp(
      {
        credential: cert({
          projectId: key.project_id,
          clientEmail: key.client_email,
          privateKey: key.private_key,
        }),
        projectId: key.project_id,
      },
      FIREBASE_APP_NAME,
    );
    firebaseApp = app;
    setPushSender(createFcmSender(getMessaging(app)));
    console.info(`[push] On: sending through the Firebase project ${key.project_id}.`);
    return true;
  } catch (err) {
    console.error('[push] Off: could not start Firebase Cloud Messaging:', err);
    return false;
  }
}

/** Turns push off and closes the Firebase app, so a script can exit. */
export async function closePush(): Promise<void> {
  const app = firebaseApp;
  if (!app) return;
  firebaseApp = null;
  setPushSender(null);
  const { deleteApp } = await import('firebase-admin/app');
  await deleteApp(app);
}
