const pool = require('./config/database');
const bus = require('./events/bus');
const queue = require('./queue');

// Записывает каждое действие над заказом в order_history — независимый
// подписчик той же шины событий, что и automation.js/notifications.js.
// Не решает НИЧЕГО о бизнес-логике, только слушает готовые теги действий,
// которые уже расставлены в orders.js/automation.js. Проходит через
// очередь (queue.js) на тех же условиях, что и notifications.js.

const ACTOR_BY_ACTION = {
  created: 'customer',
  'status:confirmed': 'system',
  picker_assigned: 'system',
  'status:packing': 'picker',
  delivery_assigned: 'system',
  'status:transit': 'delivery',
  'status:delivered': 'delivery',
  'status:completed': 'system',
  'status:cancelled': 'admin',
};

// Schema owned by migrations.js (order_history table + index).

async function processHistoryEntry({ order, action }) {
  if (!action) return;
  const actor = ACTOR_BY_ACTION[action] || 'system';
  const details = {
    status: order.status,
    picker_user_id: order.picker_user_id,
    delivery_user_id: order.delivery_user_id,
  };
  await pool.query(
    `INSERT INTO order_history (order_id, actor, action, details) VALUES ($1, $2, $3, $4)`,
    [order.id, actor, action, JSON.stringify(details)]
  );
}

function onOrderEvent(order, action) {
  // BullMQ rejects ':' anywhere in a custom job ID — action strings like
  // 'status:confirmed' have one, so it's replaced before use.
  queue.enqueue('history', `hist_${order.id}_${action.replace(/:/g, '-')}`, { order, action });
}

async function start() {
  queue.registerWorker('history', processHistoryEntry);
  bus.on('order', onOrderEvent);
  console.log(`📜 Order history logging запущен (${queue.enabled() ? 'BullMQ' : 'local'} режими)`);
}

module.exports = { start, __internals: { processHistoryEntry } };
