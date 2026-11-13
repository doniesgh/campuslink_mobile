import { createTransport, type Transporter } from 'nodemailer';

import { env } from '../../config/env';
import type { Locale } from '../../lib/i18n';

/**
 * Sends the auth emails (only the password-reset code: sign-up sends none),
 * in the recipient's language ([locale], English when not given: the auth
 * service always passes the account's). Swap the implementation with
 * [setMailer].
 */
export interface Mailer {
  sendPasswordResetCode(to: string, code: string, locale?: Locale): Promise<void>;
}

export interface EmailContent {
  subject: string;
  text: string;
  html: string;
}

const layout = (
  locale: Locale,
  title: string,
  intro: string,
  code: string,
  outro: string,
): EmailContent => ({
  subject: title,
  text: `${intro}

${code}

${outro}

— CampusPulse`,
  html: `<div lang="${locale}" style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#1e192b">
  <h2 style="color:#6949a8">${title}</h2>
  <p>${intro}</p>
  <p style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#6949a8">${code}</p>
  <p style="color:#4a4551">${outro}</p>
  <p style="color:#7b7582">— CampusPulse</p>
</div>`,
});

/** The texts of the reset email, per language. French says "tu", like the rest of the app. */
const RESET_TEXTS = {
  en: {
    title: 'Reset your CampusPulse password',
    intro: 'Enter this code in the app to choose a new password:',
    outro:
      'The code expires in 15 minutes. If you did not ask for it, ignore this email: your password stays the same.',
  },
  fr: {
    title: 'Réinitialise ton mot de passe CampusPulse',
    intro: "Saisis ce code dans l'appli pour choisir un nouveau mot de passe :",
    outro:
      "Le code expire dans 15 minutes. Si tu n'es pas à l'origine de cette demande, ignore cet e-mail : ton mot de passe ne changera pas.",
  },
} satisfies Record<Locale, { title: string; intro: string; outro: string }>;

/** [code] is always 6 digits, so it is safe to put in the HTML as-is. */
export const passwordResetEmail = (code: string, locale: Locale = 'en'): EmailContent => {
  const { title, intro, outro } = RESET_TEXTS[locale];
  return layout(locale, title, intro, code, outro);
};

/** Development mailer: prints the messages in the server console. */
export const consoleMailer: Mailer = {
  async sendPasswordResetCode(to, code, locale = 'en') {
    console.info(`[mail] Password reset code for ${to} (${locale}): ${code}`);
  },
};

/** Real emails through any SMTP server (Gmail app password, Outlook, Mailtrap, Brevo...). */
export function createSmtpMailer(transport: Pick<Transporter, 'sendMail'>, from: string): Mailer {
  const send = async (to: string, content: EmailContent) => {
    await transport.sendMail({ from, to, ...content });
  };
  return {
    sendPasswordResetCode: (to, code, locale) => send(to, passwordResetEmail(code, locale)),
  };
}

/**
 * The SMTP connection the SMTP_* settings describe, or null without
 * SMTP_HOST. Port 465 is TLS from the start; the others (587, 2525) switch to
 * TLS with STARTTLS. Also used by `npm run mail:test`.
 */
export function smtpTransportFromEnv(): Transporter | null {
  if (!env.SMTP_HOST) return null;
  return createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_PORT === 465,
    auth: env.SMTP_USER ? { user: env.SMTP_USER, pass: env.SMTP_PASS ?? '' } : undefined,
    // The password reset waits for the email, and the app gives up after
    // 20 s. Nodemailer's defaults are minutes: a blocked port (e.g. 587
    // on Render's free plan) would make those requests fail in the app.
    connectionTimeout: 8_000,
    greetingTimeout: 8_000,
    socketTimeout: 12_000,
  });
}

/** How long the API waits for the mail relay (the app gives up after 20 s). */
const RELAY_TIMEOUT_MS = 10_000;

/** "CampusPulse <me@gmail.com>" gives "CampusPulse"; a bare address gives "CampusPulse". */
export const senderName = (from: string): string =>
  /^\s*"?([^"<]+?)"?\s*</.exec(from)?.[1] ?? 'CampusPulse';

type Fetch = (url: string, init: RequestInit) => Promise<Pick<Response, 'status' | 'text'>>;

/**
 * Sends one email through the Gmail relay (a Google Apps Script web app, see
 * backend/mail-relay/gmail-relay.gs): it goes out from the script owner's
 * Gmail. Throws with a readable reason when the relay refuses it.
 */
export async function sendThroughRelay(
  relay: { url: string; secret: string; name: string },
  to: string,
  content: EmailContent,
  post: Fetch = fetch,
): Promise<void> {
  const response = await post(relay.url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ secret: relay.secret, to, name: relay.name, ...content }),
    // Apps Script answers through a redirect to googleusercontent.com.
    redirect: 'follow',
    signal: AbortSignal.timeout(RELAY_TIMEOUT_MS),
  });
  const body = await response.text();
  let answer: { ok?: unknown; error?: unknown };
  try {
    answer = JSON.parse(body) as typeof answer;
  } catch {
    throw new Error(
      `The mail relay answered ${response.status} with a page, not JSON: is the web app ` +
        'deployed with "Who has access: Anyone", and is MAIL_RELAY_URL its /exec URL?',
    );
  }
  if (answer.ok !== true) {
    throw new Error(`The mail relay refused the email: ${String(answer.error ?? 'no reason given')}`);
  }
}

/** Real emails from a Gmail account, through the Apps Script relay. */
export function createRelayMailer(
  relay: { url: string; secret: string; name: string },
  post: Fetch = fetch,
): Mailer {
  const send = (to: string, content: EmailContent) => sendThroughRelay(relay, to, content, post);
  return {
    sendPasswordResetCode: (to, code, locale) => send(to, passwordResetEmail(code, locale)),
  };
}

/** The relay settings, or null when MAIL_RELAY_URL is empty. */
export function relayFromEnv(): { url: string; secret: string; name: string } | null {
  if (!env.MAIL_RELAY_URL) return null;
  return { url: env.MAIL_RELAY_URL, secret: env.MAIL_RELAY_SECRET ?? '', name: senderName(env.SMTP_FROM) };
}

/**
 * The Gmail relay when MAIL_RELAY_URL is set, else SMTP when SMTP_HOST is set
 * (see .env.example), else the console.
 */
function defaultMailer(): Mailer {
  const relay = relayFromEnv();
  if (relay) return createRelayMailer(relay);
  const transport = smtpTransportFromEnv();
  return transport ? createSmtpMailer(transport, env.SMTP_FROM) : consoleMailer;
}

let current: Mailer = defaultMailer();

export const setMailer = (mailer: Mailer): void => {
  current = mailer;
};

export const mailer: Mailer = {
  sendPasswordResetCode: (to, code, locale) => current.sendPasswordResetCode(to, code, locale),
};
