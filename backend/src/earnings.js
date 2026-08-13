const pool = require('./config/database');
const bus = require('./events/bus');
const queue = require('./queue');

// Автоматический расчёт вознаграждения сборщика и курьера. Срабатывает в
// момент, когда курьер отмечает заказ доставленным (action 'status:delivered')
// — именно тогда обе роли завершили свою часть работы по этому заказу.
// Проходит через очередь (queue.js) на тех же условиях, что и
// notifications.js/history.js.
//
// Ставки — фиксированная сумма за заказ, хранится в settings (key
// 'earnings'), тот же паттерн key/value jsonb, что и automation.js. Не
// проценты от суммы заказа: без данных о себестоимости товара процент от
// total не отражал бы реальный доход платформы — это осознанное упрощение,
// см. итоговый отчёт.

const DEFAULTS = { pickerFee: 50, deliveryFee: 100 };

let rates = { ...DEFAULTS };

// Schema owned by migrations.js (settings + earnings tables).

async function loadRates() {
  const { rows } = await pool.query(`SELECT value FROM settings WHERE key = 'earnings'`);
  rates = { ...DEFAULTS, ...(rows[0]?.value || {}) };
  return rates;
}

function getRates() {
  return rates;
}

async function saveRates(patch) {
  rates = { ...rates, ...patch };
  await pool.query(
    `INSERT INTO settings (key, value, updated_at) VALUES ('earnings', $1, NOW())
     ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = NOW()`,
    [JSON.stringify(rates)]
  );
  return rates;
}

// ON CONFLICT DO NOTHING делает это идемпотентным на уровне БД — вдобавок
// к идемпотентности на уровне очереди (deterministic jobId) — если
// 'status:delivered' придёт дважды, начисление не задвоится ни при каком
// сценарии повтора.
async function processPayout({ order }) {
  if (order.picker_user_id) {
    await pool.query(
      `INSERT INTO earnings (user_id, order_id, role, amount) VALUES ($1, $2, 'picker', $3)
       ON CONFLICT (order_id, role) DO NOTHING`,
      [order.picker_user_id, order.id, rates.pickerFee]
    );
  }
  if (order.delivery_user_id) {
    await pool.query(
      `INSERT INTO earnings (user_id, order_id, role, amount) VALUES ($1, $2, 'delivery', $3)
       ON CONFLICT (order_id, role) DO NOTHING`,
      [order.delivery_user_id, order.id, rates.deliveryFee]
    );
  }
}

function onOrderEvent(order, action) {
  if (action === 'status:delivered') {
    // BullMQ rejects ':' anywhere in a custom job ID.
    queue.enqueue('earnings', `payout_${order.id}`, { order });
  }
}

async function start() {
  await loadRates();
  queue.registerWorker('earnings', processPayout);
  bus.on('order', onOrderEvent);
  console.log(`💵 Earnings запущен (ставки: ${JSON.stringify(rates)}, ${queue.enabled() ? 'BullMQ' : 'local'} режими)`);
}

module.exports = { start, getRates, saveRates, __internals: { processPayout } };
