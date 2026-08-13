const logger = require('./logger');
const queue = require('./queue');

// Email infrastructure — a real queue + worker, wired to nothing yet. The
// product has no email flow today (no password reset, no order receipts by
// email — customer notifications already go through notifications.js's SSE
// + in-app table). This exists so a future feature (password reset, a
// receipt email) has a retry-capable delivery mechanism to plug into
// immediately, instead of that feature needing to build one from scratch.
//
// Without SMTP_HOST configured, sendEmail() logs what it would have sent
// and returns — safe to call in any environment, never throws for a
// missing configuration.
let transporter = null;

function getTransporter() {
  if (!process.env.SMTP_HOST) return null;
  if (!transporter) {
    const nodemailer = require('nodemailer');
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT) || 587,
      secure: process.env.SMTP_SECURE === 'true',
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASSWORD } : undefined,
    });
  }
  return transporter;
}

async function processEmail({ to, subject, text, html }) {
  const t = getTransporter();
  if (!t) {
    logger.info({ to, subject }, 'SMTP туураланган эмес — email жөнөтүлгөн жок (dev/no-op)');
    return;
  }
  await t.sendMail({ from: process.env.SMTP_FROM || 'no-reply@daily.kg', to, subject, text, html });
}

// Call from any future feature: email.enqueue({ to, subject, text }).
// Goes through queue.js the same as notifications/history/earnings — retry
// + backoff + dead-letter with Redis, direct-call fallback without it.
function enqueue({ to, subject, text, html }) {
  // BullMQ rejects ':' anywhere in a custom job ID; no natural dedup key
  // for an arbitrary email, so timestamped instead.
  const jobKey = `email_${to.replace(/[^a-zA-Z0-9]/g, '-')}_${Date.now()}`;
  return queue.enqueue('email', jobKey, { to, subject, text, html });
}

function start() {
  queue.registerWorker('email', processEmail);
  console.log(`📧 Email queue даяр (${queue.enabled() ? 'BullMQ' : 'local'} режими, SMTP: ${process.env.SMTP_HOST ? 'туураланган' : 'туураланган эмес'})`);
}

module.exports = { start, enqueue, __internals: { processEmail } };
