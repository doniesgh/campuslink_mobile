/**
 * CampusPulse mail relay: sends the API's emails (sign-up and password-reset
 * codes) from the Gmail of the Google account that owns this script.
 *
 * Why: Render's free plan blocks the SMTP ports Gmail uses (465, 587). The API
 * calls this script over HTTPS instead, and Google sends the email.
 *
 * Setup (docs/deploy.md › Emails):
 *   1. script.google.com › New project, paste this file in place of Code.gs, save.
 *   2. Project Settings › Script Properties › Add: SECRET = the API's MAIL_RELAY_SECRET.
 *   3. Deploy › New deployment › Web app. Execute as: Me. Who has access: Anyone.
 *      Authorize it (your own script: Advanced › Go to … › Allow).
 *   4. Copy the Web app URL (…/exec) into the API's MAIL_RELAY_URL.
 * After editing this file: Deploy › Manage deployments › Edit › Version: New version.
 *
 * Limits: a personal Gmail account sends to at most 100 recipients a day this
 * way (MailApp quota).
 */

/** The API posts { secret, to, subject, text, html, name }. Answers { ok } as JSON. */
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const secret = PropertiesService.getScriptProperties().getProperty('SECRET');
    if (!secret || data.secret !== secret) {
      return answer({ ok: false, error: 'Wrong secret: SECRET must equal MAIL_RELAY_SECRET.' });
    }
    if (!data.to || !data.subject) {
      return answer({ ok: false, error: 'An email needs "to" and "subject".' });
    }
    MailApp.sendEmail({
      to: data.to,
      subject: data.subject,
      body: data.text || '',
      htmlBody: data.html || undefined,
      name: data.name || 'CampusPulse',
    });
    return answer({ ok: true, remainingToday: MailApp.getRemainingDailyQuota() });
  } catch (err) {
    return answer({ ok: false, error: String((err && err.message) || err) });
  }
}

/** Opening the URL in a browser shows that the relay is deployed. */
function doGet() {
  return answer({ ok: true, service: 'CampusPulse mail relay', remainingToday: MailApp.getRemainingDailyQuota() });
}

function answer(value) {
  return ContentService.createTextOutput(JSON.stringify(value)).setMimeType(ContentService.MimeType.JSON);
}
