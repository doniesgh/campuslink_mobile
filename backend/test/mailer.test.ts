import {
  createSmtpMailer,
  passwordResetEmail,
  verificationEmail,
} from '../src/modules/auth/mailer';

describe('createSmtpMailer', () => {
  test('sends the verification code from the configured address', async () => {
    const sendMail = jest.fn().mockResolvedValue({});
    const mailer = createSmtpMailer({ sendMail }, 'CampusPulse <no-reply@campus.test>');

    await mailer.sendVerificationCode('sarra@campus.test', '042917');

    expect(sendMail).toHaveBeenCalledTimes(1);
    const message = sendMail.mock.calls[0][0];
    expect(message).toMatchObject({
      from: 'CampusPulse <no-reply@campus.test>',
      to: 'sarra@campus.test',
      subject: 'Verify your CampusPulse email',
    });
    expect(message.text).toContain('042917');
    expect(message.html).toContain('042917');
  });

  test('sends the password reset code', async () => {
    const sendMail = jest.fn().mockResolvedValue({});
    await createSmtpMailer({ sendMail }, 'x@campus.test').sendPasswordResetCode('a@b.c', '123456');
    expect(sendMail.mock.calls[0][0]).toMatchObject({
      to: 'a@b.c',
      subject: 'Reset your CampusPulse password',
    });
  });

  test('passes SMTP errors to the caller (the auth service logs them)', async () => {
    const mailer = createSmtpMailer(
      { sendMail: jest.fn().mockRejectedValue(new Error('SMTP down')) },
      'x@campus.test',
    );
    await expect(mailer.sendVerificationCode('a@b.c', '123456')).rejects.toThrow('SMTP down');
  });
});

test('email contents mention the code and its expiry', () => {
  for (const email of [verificationEmail('654321'), passwordResetEmail('654321')]) {
    expect(email.text).toContain('654321');
    expect(email.text).toContain('15 minutes');
  }
});
