import { env } from '../config/env';
import {
  relayFromEnv,
  sendThroughRelay,
  smtpTransportFromEnv,
  type EmailContent,
} from '../modules/auth/mailer';

/**
 * Checks the email settings by sending a test email, the same way the API
 * sends the password-reset codes: through the Gmail relay when
 * MAIL_RELAY_URL is set, else through SMTP_*.
 *
 *   npm run mail:test -- <your email address>
 *   npm run mail:test                (sends it to the address of SMTP_FROM)
 *
 * Says what is wrong in plain words, and never prints a password or secret.
 */
const USAGE = 'Usage: npm run mail:test -- <your email address>';

const TEST_EMAIL: EmailContent = {
  subject: 'CampusPulse email test',
  text: 'If you can read this, CampusPulse can send its password-reset codes.\n\n— CampusPulse',
  html:
    '<p>If you can read this, CampusPulse can send its password-reset codes.</p>' +
    '<p>— CampusPulse</p>',
};

function explainSmtp(err: unknown): string {
  const { code, responseCode, response } = err as {
    code?: string;
    responseCode?: number;
    response?: string;
  };
  const message = err instanceof Error ? err.message : String(err);
  if (code === 'EAUTH' || responseCode === 535 || responseCode === 534) {
    return [
      'The SMTP login is refused (SMTP_USER / SMTP_PASS).',
      '  - Gmail: SMTP_PASS is an app password (myaccount.google.com/apppasswords, needs',
      '    2-Step Verification), without its spaces, not your Google password.',
      '  - Brevo: SMTP_USER is the SMTP login shown under SMTP & API > SMTP (…@smtp-brevo.com),',
      '    and SMTP_PASS an SMTP key generated there, not your Brevo account password.',
    ].join('\n');
  }
  if (['ETIMEDOUT', 'ECONNECTION', 'ESOCKET', 'ECONNREFUSED', 'ENOTFOUND'].includes(code ?? '')) {
    return [
      `Can't reach ${env.SMTP_HOST}:${env.SMTP_PORT} (${code}).`,
      '  - Check SMTP_HOST and SMTP_PORT.',
      '  - Render free web services block ports 25, 465 and 587: use the Gmail relay there',
      '    (MAIL_RELAY_URL, see docs/deploy.md).',
      '  - A school or company network may block SMTP too: try from another connection.',
    ].join('\n');
  }
  if ((responseCode ?? 0) >= 500 && /sender|from|not (allowed|authori[sz]ed)|verif/i.test(response ?? message)) {
    return `The sending address is refused: ${response ?? message}\n  SMTP_FROM must be an address this login may send from.`;
  }
  return response ?? message;
}

async function relayTest(relay: NonNullable<ReturnType<typeof relayFromEnv>>, to: string): Promise<void> {
  // The URL isn't secret (the relay checks MAIL_RELAY_SECRET), but it's long.
  console.info(`Gmail relay: ${relay.url.slice(0, 48)}… · sender name: ${relay.name}`);
  try {
    await sendThroughRelay(relay, to, TEST_EMAIL);
    console.info(`Sent to ${to} through the Gmail relay. Check the inbox, and the spam folder.`);
  } catch (err) {
    const timedOut = err instanceof Error && err.name === 'TimeoutError';
    const reason = timedOut ? 'The relay did not answer within 10 s.' : err instanceof Error ? err.message : String(err);
    console.error(`Failed: ${reason}`);
    process.exitCode = 1;
  }
}

async function smtpTest(to: string): Promise<void> {
  const transport = smtpTransportFromEnv();
  if (!transport) {
    console.info(
      'Neither MAIL_RELAY_URL nor SMTP_HOST is set: the API prints the emails (codes) in its ' +
        'console instead of sending them.',
    );
    process.exitCode = 1;
    return;
  }
  console.info(
    `SMTP: ${env.SMTP_HOST}:${env.SMTP_PORT} · login: ${env.SMTP_USER ?? '(none)'} · from: ${env.SMTP_FROM}`,
  );
  try {
    await transport.verify();
    console.info('Connected and signed in.');
    const info = await transport.sendMail({ from: env.SMTP_FROM, to, ...TEST_EMAIL });
    console.info(`Sent to ${to} (${info.response}). Check the inbox, and the spam folder.`);
  } catch (err) {
    console.error(`Failed: ${explainSmtp(err)}`);
    process.exitCode = 1;
  } finally {
    transport.close();
  }
}

/** The address of SMTP_FROM ("CampusPulse <me@gmail.com>" gives "me@gmail.com"). */
const fromAddress = (): string => (/<([^>]+)>/.exec(env.SMTP_FROM)?.[1] ?? env.SMTP_FROM).trim();

// Without an argument, the test goes to the sender's own mailbox.
const to = process.argv[2]?.trim() || fromAddress();
if (!to.includes('@') || to.endsWith('@campuspulse.test')) {
  console.error(`${USAGE}\n(Or set SMTP_FROM to your address: the test then goes there.)`);
  process.exitCode = 1;
} else {
  const relay = relayFromEnv();
  void (relay ? relayTest(relay, to) : smtpTest(to));
}
