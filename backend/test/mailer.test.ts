import {
  createRelayMailer,
  createSmtpMailer,
  passwordResetEmail,
  senderName,
  verificationEmail,
} from '../src/modules/auth/mailer';

describe('createRelayMailer (Gmail through Google Apps Script)', () => {
  const relay = {
    url: 'https://script.google.com/macros/s/abc123/exec',
    secret: 'relay-secret-0123456789',
    name: 'CampusPulse',
  };
  /** A fake fetch answering [body] with [status]. */
  const answering = (status: number, body: string) =>
    jest.fn().mockResolvedValue({ status, text: () => Promise.resolve(body) });

  test('posts the email with the secret as JSON, and follows the redirect', async () => {
    const post = answering(200, JSON.stringify({ ok: true, remainingToday: 99 }));

    await createRelayMailer(relay, post).sendVerificationCode('sarra@campus.test', '042917');

    expect(post).toHaveBeenCalledTimes(1);
    const [url, init] = post.mock.calls[0] as [string, RequestInit];
    expect(url).toBe(relay.url);
    expect(init).toMatchObject({
      method: 'POST',
      redirect: 'follow',
      headers: { 'Content-Type': 'application/json' },
    });
    const body = JSON.parse(init.body as string);
    expect(body).toMatchObject({
      secret: relay.secret,
      to: 'sarra@campus.test',
      name: 'CampusPulse',
      subject: 'Verify your CampusPulse email',
    });
    expect(body.text).toContain('042917');
    expect(body.html).toContain('042917');
  });

  test("the relay's refusal becomes an error with its reason (the auth service logs it)", async () => {
    const post = answering(200, JSON.stringify({ ok: false, error: 'Wrong secret.' }));
    await expect(
      createRelayMailer(relay, post).sendPasswordResetCode('a@b.c', '123456'),
    ).rejects.toThrow('The mail relay refused the email: Wrong secret.');
  });

  test('a web page instead of JSON (wrong access or URL) says what to check', async () => {
    const post = answering(200, '<html><title>Sign in - Google Accounts</title></html>');
    await expect(
      createRelayMailer(relay, post).sendVerificationCode('a@b.c', '123456'),
    ).rejects.toThrow('Who has access: Anyone');
  });

  test('network errors reach the caller', async () => {
    const post = jest.fn().mockRejectedValue(new TypeError('fetch failed'));
    await expect(
      createRelayMailer(relay, post).sendVerificationCode('a@b.c', '123456'),
    ).rejects.toThrow('fetch failed');
  });
});

test('the sender name comes from SMTP_FROM', () => {
  expect(senderName('CampusPulse <me@gmail.com>')).toBe('CampusPulse');
  expect(senderName('"Campus Pulse" <me@gmail.com>')).toBe('Campus Pulse');
  expect(senderName('me@gmail.com')).toBe('CampusPulse');
});

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
