import { env } from '../config/env';
import { smtpTransportFromEnv } from '../modules/auth/mailer';

/**
 * Checks the SMTP_* settings by sending a test email, the same way the API
 * sends the sign-up and password-reset codes:
 *
 *   npm run mail:test -- <your email address>
 *   npm run mail:test                (sends it to the address of SMTP_FROM)
 *
 * Says what is wrong in plain words, and never prints the password.
 */
const USAGE = 'Usage: npm run mail:test -- <your email address>';

function explain(err: unknown): string {
  const { code, responseCode, response } = err as {
    code?: string;
    responseCode?: number;
    response?: string;
  };
  const message = err instanceof Error ? err.message : String(err);
  if (code === 'EAUTH' || responseCode === 535 || responseCode === 534) {
    return [
      'The SMTP login is refused (SMTP_USER / SMTP_PASS).',
      '  - Brevo: SMTP_USER is the SMTP login shown under SMTP & API > SMTP (…@smtp-brevo.com),',
      '    and SMTP_PASS an SMTP key generated there, not your Brevo account password.',
      '  - Gmail: SMTP_PASS is an app password (myaccount.google.com/apppasswords, needs',
      '    2-Step Verification), not your Google password.',
    ].join('\n');
  }
  if (['ETIMEDOUT', 'ECONNECTION', 'ESOCKET', 'ECONNREFUSED', 'ENOTFOUND'].includes(code ?? '')) {
    return [
      `Can't reach ${env.SMTP_HOST}:${env.SMTP_PORT} (${code}).`,
      '  - Check SMTP_HOST and SMTP_PORT.',
      '  - Render free web services block ports 25, 465 and 587: use Brevo on port 2525 there.',
      '  - A school or company network may block SMTP too: try from another connection.',
    ].join('\n');
  }
  if ((responseCode ?? 0) >= 500 && /sender|from|not (allowed|authori[sz]ed)|verif/i.test(response ?? message)) {
    return `The sending address is refused: ${response ?? message}\n  Brevo: verify the address of SMTP_FROM under Senders (Settings > Senders, Domains & Dedicated IPs).`;
  }
  return response ?? message;
}

async function mailTest(to: string): Promise<void> {
  const transport = smtpTransportFromEnv();
  if (!transport) {
    console.info(
      'SMTP_HOST is empty: the API prints the emails (codes) in its console instead of sending them.',
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
    const info = await transport.sendMail({
      from: env.SMTP_FROM,
      to,
      subject: 'CampusPulse email test',
      text: 'If you can read this, CampusPulse can send its sign-up and password-reset codes.\n\n— CampusPulse',
    });
    console.info(`Sent to ${to} (${info.response}). Check the inbox, and the spam folder.`);
  } catch (err) {
    console.error(`Failed: ${explain(err)}`);
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
  void mailTest(to);
}
