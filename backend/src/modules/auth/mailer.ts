import { createTransport, type Transporter } from 'nodemailer';

import { env } from '../../config/env';

/** Sends the auth emails. Swap the implementation with [setMailer]. */
export interface Mailer {
  sendVerificationCode(to: string, code: string): Promise<void>;
  sendPasswordResetCode(to: string, code: string): Promise<void>;
}

export interface EmailContent {
  subject: string;
  text: string;
  html: string;
}

const layout = (title: string, intro: string, code: string, outro: string): EmailContent => ({
  subject: title,
  text: `${intro}\n\n${code}\n\n${outro}\n\n— CampusPulse`,
  html: `<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#1e192b">
  <h2 style="color:#6949a8">${title}</h2>
  <p>${intro}</p>
  <p style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#6949a8">${code}</p>
  <p style="color:#4a4551">${outro}</p>
  <p style="color:#7b7582">— CampusPulse</p>
</div>`,
});

/** [code] is always 6 digits, so it is safe to put in the HTML as-is. */
export const verificationEmail = (code: string): EmailContent =>
  layout(
    'Verify your CampusPulse email',
    'Welcome to CampusPulse! Enter this code in the app to verify your email:',
    code,
    'The code expires in 15 minutes. If you did not create an account, ignore this email.',
  );

export const passwordResetEmail = (code: string): EmailContent =>
  layout(
    'Reset your CampusPulse password',
    'Enter this code in the app to choose a new password:',
    code,
    'The code expires in 15 minutes. If you did not ask for it, ignore this email: your password stays the same.',
  );

/** Development mailer: prints the messages in the server console. */
export const consoleMailer: Mailer = {
  async sendVerificationCode(to, code) {
    console.info(`[mail] Verification code for ${to}: ${code}`);
  },
  async sendPasswordResetCode(to, code) {
    console.info(`[mail] Password reset code for ${to}: ${code}`);
  },
};

/** Real emails through any SMTP server (Gmail app password, Outlook, Mailtrap, Brevo...). */
export function createSmtpMailer(transport: Pick<Transporter, 'sendMail'>, from: string): Mailer {
  const send = async (to: string, content: EmailContent) => {
    await transport.sendMail({ from, to, ...content });
  };
  return {
    sendVerificationCode: (to, code) => send(to, verificationEmail(code)),
    sendPasswordResetCode: (to, code) => send(to, passwordResetEmail(code)),
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
  });
}

/** SMTP when SMTP_HOST is set (see .env.example), the console otherwise. */
function defaultMailer(): Mailer {
  const transport = smtpTransportFromEnv();
  return transport ? createSmtpMailer(transport, env.SMTP_FROM) : consoleMailer;
}

let current: Mailer = defaultMailer();

export const setMailer = (mailer: Mailer): void => {
  current = mailer;
};

export const mailer: Mailer = {
  sendVerificationCode: (to, code) => current.sendVerificationCode(to, code),
  sendPasswordResetCode: (to, code) => current.sendPasswordResetCode(to, code),
};
