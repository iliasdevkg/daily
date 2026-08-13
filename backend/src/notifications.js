const pool = require('./config/database');
const bus = require('./events/bus');
const queue = require('./queue');

// Уведомления клиенту на каждом этапе заказа. Слушает те же теги действий,
// что и history.js, пишет в таблицу notifications и заново эмитит их через
// bus как 'notification' — routes/events.js пересылает это клиенту по SSE,
// если он сейчас подключён (offline-клиент увидит уведомление при следующем
// заходе через GET /api/notifications/my).
//
// Обработка идёт через queue.js — с Redis это реальная BullMQ-очередь
// (retry + backoff + dead-letter при исчерпании попыток), без Redis —
// прямой вызов, как было раньше. Место вызова (см. start()) не отличается
// в обоих режимах.
//
// «Курьер жакындады» из ТЗ не реализовано: в схеме нет геолокации заказа/
// курьера (lat/lng нигде не хранится), присылать такое уведомление было бы
// нечем измерить — см. итоговый отчёт, раздел «на будущее».

const MESSAGE_BY_ACTION = {
  created: { title: 'Заказ кабыл алынды', message: 'Сиздин заказыңыз кабыл алынды, азыр текшерилет.' },
  'status:confirmed': { title: 'Заказ ырасталды', message: 'Заказыңыз ырасталды жана жыйноого даярдалууда.' },
  picker_assigned: { title: 'Жыйноочу дайындалды', message: 'Заказыңызды жыйноочу колго алды.' },
  'status:packing': { title: 'Жыйноо башталды', message: 'Заказыңыз жыйналып жатат.' },
  delivery_assigned: { title: 'Курьер дайындалды', message: 'Заказыңызды жеткирүүчү курьер дайындалды.' },
  'status:transit': { title: 'Курьер жолдо', message: 'Курьер заказыңыз менен жолго чыкты.' },
  'status:delivered': { title: 'Заказ жеткирилди', message: 'Заказыңыз ийгиликтүү жеткирилди. Ирденигиз үчүн рахмат!' },
  'status:completed': { title: 'Заказ аяктады', message: 'Заказ толук аяктады.' },
  'status:cancelled': { title: 'Заказ жокко чыгарылды', message: 'Заказыңыз жокко чыгарылды.' },
};

// Schema owned by migrations.js (notifications table + index).

// The queue worker's processor — throws on failure so BullMQ (Redis mode)
// or the local fallback (see queue.js) both see it as a real failure and
// log/retry accordingly, instead of the error being silently swallowed.
async function processNotification({ order, action }) {
  const template = MESSAGE_BY_ACTION[action];
  if (!template || !order.user_id) return;
  const { rows } = await pool.query(
    `INSERT INTO notifications (user_id, order_id, title, message) VALUES ($1, $2, $3, $4) RETURNING *`,
    [order.user_id, order.id, template.title, template.message]
  );
  bus.emit('notification', rows[0]); // routes/events.js forwards this to the owning customer's SSE stream
}

function onOrderEvent(order, action) {
  // Deterministic jobId: the same (order, action) enqueued twice (e.g. a
  // duplicate bus event) collapses into one job instead of double-sending.
  // BullMQ rejects ':' anywhere in a custom job ID (Redis key-namespace
  // separator internally) — action strings like 'status:confirmed' have
  // one, so it's replaced, not just the prefix's own separator.
  queue.enqueue('notifications', `notif_${order.id}_${action.replace(/:/g, '-')}`, { order, action });
}

async function start() {
  queue.registerWorker('notifications', processNotification);
  bus.on('order', onOrderEvent);
  console.log(`🔔 Customer notifications запущен (${queue.enabled() ? 'BullMQ' : 'local'} режими)`);
}

module.exports = { start, __internals: { processNotification } };
