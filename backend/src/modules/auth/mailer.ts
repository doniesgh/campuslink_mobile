/** Sends the auth emails. Swap the implementation with [setMailer]. */
export interface Mailer {
  sendVerificationCode(to: string, code: string): Promise<void>;
  sendPasswordReset(to: string, token: string): Promise<void>;
}

/**
 * Development mailer: prints the messages in the server console instead of
 * sending them. TODO: SMTP (e.g. nodemailer) for production.
 */
export const consoleMailer: Mailer = {
  async sendVerificationCode(to, code) {
    console.info(`[mail] Verification code for ${to}: ${code}`);
  },
  async sendPasswordReset(to, token) {
    console.info(`[mail] Password reset token for ${to}: ${token}`);
  },
};

let current: Mailer = consoleMailer;

export const setMailer = (mailer: Mailer): void => {
  current = mailer;
};

export const mailer: Mailer = {
  sendVerificationCode: (to, code) => current.sendVerificationCode(to, code),
  sendPasswordReset: (to, token) => current.sendPasswordReset(to, token),
};
