const router = require('express').Router();
const jwt = require('jsonwebtoken');
const bus = require('../events/bus');

// The browser's native EventSource API cannot send custom headers, so it
// can't use the normal Authorization-header auth from middleware/auth.js.
// The token travels as a query param instead — same JWT, same secret.
function authenticateFromQuery(req, res, next) {
  const token = req.query.token;
  if (!token) return res.status(401).json({ message: 'Токен отсутствует' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ message: 'Недействительный токен' });
  }
}

// Mirrors the visibility rules already used by GET /orders, /orders/picker,
// /orders/delivery and /orders/my — a role only gets notified about orders
// it would actually be allowed to fetch.
function isVisibleTo(user, order) {
  if (user.role === 'admin') return true;
  if (user.role === 'picker') {
    return order.picker_user_id === user.id || ['confirmed', 'packing'].includes(order.status);
  }
  if (user.role === 'delivery') {
    return order.delivery_user_id === user.id || (order.status === 'transit' && !order.delivery_user_id);
  }
  if (user.role === 'customer') return order.user_id === user.id;
  return false;
}

// GET /api/events?token=<jwt> — Server-Sent Events stream.
router.get('/', authenticateFromQuery, (req, res) => {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-transform',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.flushHeaders();

  const send = (event, data) => {
    res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
  };
  send('connected', { ok: true });

  const onOrderChanged = (order) => {
    if (isVisibleTo(req.user, order)) send('order', order);
  };
  bus.on('order', onOrderChanged);

  // Push a notification the instant notifications.js writes it — only to
  // the customer it belongs to. If they're offline it just waits in the
  // notifications table for GET /api/notifications/my on next login.
  const onNotification = (notification) => {
    if (notification.user_id === req.user.id) send('notification', notification);
  };
  bus.on('notification', onNotification);

  // New picker/courier/admin registered, or a role changed — lets the
  // admin Dashboard update its people counts without a manual refresh.
  const onUserChanged = (user) => {
    if (req.user.role === 'admin') send('user', user);
  };
  bus.on('user', onUserChanged);

  // Render's free tier (and most proxies) will drop an HTTP connection that
  // stays silent too long. A comment-only heartbeat — invisible to
  // EventSource's message parsing — keeps it alive.
  const heartbeat = setInterval(() => res.write(': ping\n\n'), 25000);

  req.on('close', () => {
    clearInterval(heartbeat);
    bus.off('order', onOrderChanged);
    bus.off('notification', onNotification);
    bus.off('user', onUserChanged);
  });
});

module.exports = router;
