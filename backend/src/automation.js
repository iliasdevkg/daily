const pool = require('./config/database');
const bus = require('./events/bus');
const metrics = require('./metrics');

// Движок автоматизации заказов. Настройки хранятся в таблице settings
// (key/value jsonb) и управляются админом через /api/settings/automation.
//
// Каскад работает через ту же шину событий, что и SSE: каждое действие
// обновляет заказ и заново эмитит 'order' с тегом действия, так что
// следующий шаг цепочки (и все подключённые клиенты — SSE, notifications.js,
// history.js, earnings.js) видят его сразу. Зацикливание невозможно —
// каждый шаг срабатывает только пока его условие не выполнено (guard в SQL).
//
//   pending ──автоподтверждение──▶ confirmed ──автоназначение──▶ сборщик
//   packing/transit ──автоназначение──▶ курьер (наименее загруженный)
//   delivered ──(таймер)──▶ completed
//
// Каждый шаг идемпотентен (SQL WHERE не даёт применить его дважды), поэтому
// периодический sweep() ниже одновременно служит и "догонялкой" для заказов,
// пропущенных из-за рестарта сервера, и retry-механизмом для шагов, упавших
// с ошибкой — на следующем проходе они просто пробуются снова.

const DEFAULTS = {
  autoConfirm: true,          // pending → confirmed без участия админа
  autoAssignPicker: true,     // confirmed/packing без сборщика → наименее загруженный сборщик
  autoAssignDelivery: true,   // packing/transit без курьера → наименее загруженный курьер
  autoComplete: true,         // delivered → completed через completeAfterMinutes
  completeAfterMinutes: 15,
};

const SWEEP_INTERVAL_MS = 60 * 1000;

let settings = { ...DEFAULTS };
let sweepTimer = null;
// Schema (settings, automation_errors tables; delivered_at/completed_at
// columns) is owned by migrations.js, applied once at app startup before
// any module's start() runs — see app.js.

async function loadSettings() {
  const { rows } = await pool.query(`SELECT value FROM settings WHERE key = 'automation'`);
  settings = { ...DEFAULTS, ...(rows[0]?.value || {}) };
  return settings;
}

function getSettings() {
  return settings;
}

async function saveSettings(patch) {
  settings = { ...settings, ...patch };
  await pool.query(
    `INSERT INTO settings (key, value, updated_at) VALUES ('automation', $1, NOW())
     ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = NOW()`,
    [JSON.stringify(settings)]
  );
  // Включённое правило сразу применяется к накопившимся заказам.
  sweep().catch((err) => console.error('Automation sweep error:', err.message));
  return settings;
}

// Fail-safe: каждая ошибка автоматизации попадает сюда вместо того, чтобы
// молча теряться в консоли — админ видит её на странице «Автоматизация»
// через GET /api/settings/automation-errors.
async function logError(orderId, step, message) {
  try {
    await pool.query(
      `INSERT INTO automation_errors (order_id, step, error_message) VALUES ($1, $2, $3)`,
      [orderId, step, message]
    );
  } catch (err) {
    console.error('Failed to log automation error:', err.message);
  }
}

async function resolveErrors(orderId) {
  await pool.query(
    `UPDATE automation_errors SET resolved = true WHERE order_id = $1 AND resolved = false`,
    [orderId]
  );
}

async function getErrors() {
  const { rows } = await pool.query(
    `SELECT * FROM automation_errors WHERE resolved = false ORDER BY created_at DESC LIMIT 50`
  );
  return rows;
}

// Наименее загруженный сотрудник роли: считает только активные заказы.
// Принимает client, а не pool — вызывающая сторона держит его внутри
// транзакции с advisory-lock'ом (см. autoAssignPicker/autoAssignDelivery).
async function leastBusy(client, role, activeStatuses, assignColumn) {
  const { rows } = await client.query(
    `SELECT u.id FROM users u
     LEFT JOIN orders o ON o.${assignColumn} = u.id AND o.status = ANY($2)
     WHERE u.role = $1
     GROUP BY u.id ORDER BY COUNT(o.id) ASC, u.id ASC LIMIT 1`,
    [role, activeStatuses]
  );
  return rows[0]?.id || null;
}

async function autoConfirm(order) {
  const { rows } = await pool.query(
    `UPDATE orders SET status = 'confirmed' WHERE id = $1 AND status = 'pending' RETURNING *`,
    [order.id]
  );
  if (rows[0]) {
    console.log(`⚡ Автоматизация: заказ #${order.id} подтверждён`);
    metrics.automationActionsTotal.inc({ action: 'auto_confirm' });
    bus.emit('order', rows[0], 'status:confirmed');
  }
}

// Race fix: without a lock, two orders confirmed in the same instant can
// both run leastBusy() before either UPDATE commits, see the same picker
// with 0 active orders, and both assign to them — not a double-assignment
// of one order (the WHERE picker_user_id IS NULL guard still prevents
// that), but a real fairness bug where one picker gets buried and another
// stays idle. pg_advisory_xact_lock serializes the read-then-write
// "who's least busy" decision across concurrent calls for the same role;
// the lock is released automatically on COMMIT/ROLLBACK.
async function autoAssignPicker(order) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', ['assign:picker']);
    const pickerId = await leastBusy(client, 'picker', ['confirmed', 'packing'], 'picker_user_id');
    if (!pickerId) { await client.query('ROLLBACK'); return; } // нет свободных — sweep() повторит позже
    const { rows } = await client.query(
      `UPDATE orders SET picker_user_id = $1
       WHERE id = $2 AND picker_user_id IS NULL AND status IN ('confirmed','packing') RETURNING *`,
      [pickerId, order.id]
    );
    await client.query('COMMIT');
    if (rows[0]) {
      console.log(`⚡ Автоматизация: заказ #${order.id} → сборщик #${pickerId}`);
      metrics.automationActionsTotal.inc({ action: 'auto_assign_picker' });
      bus.emit('order', rows[0], 'picker_assigned');
    }
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function autoAssignDelivery(order) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', ['assign:delivery']);
    const driverId = await leastBusy(client, 'delivery', ['packing', 'transit'], 'delivery_user_id');
    if (!driverId) { await client.query('ROLLBACK'); return; }
    const { rows } = await client.query(
      `UPDATE orders SET delivery_user_id = $1
       WHERE id = $2 AND delivery_user_id IS NULL AND status IN ('packing','transit') RETURNING *`,
      [driverId, order.id]
    );
    await client.query('COMMIT');
    if (rows[0]) {
      console.log(`⚡ Автоматизация: заказ #${order.id} → курьер #${driverId}`);
      metrics.automationActionsTotal.inc({ action: 'auto_assign_delivery' });
      bus.emit('order', rows[0], 'delivery_assigned');
    }
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function autoComplete(order) {
  const { rows } = await pool.query(
    `UPDATE orders SET status = 'completed', completed_at = NOW()
     WHERE id = $1 AND status = 'delivered'
       AND delivered_at IS NOT NULL
       AND delivered_at <= NOW() - ($2 || ' minutes')::interval
     RETURNING *`,
    [order.id, settings.completeAfterMinutes]
  );
  if (rows[0]) {
    console.log(`⚡ Автоматизация: заказ #${order.id} завершён (completed)`);
    metrics.automationActionsTotal.inc({ action: 'auto_complete' });
    bus.emit('order', rows[0], 'status:completed');
  }
}

async function handleOrder(order) {
  try {
    if (settings.autoConfirm && order.status === 'pending') {
      await autoConfirm(order); // подтверждение заново эмитит заказ — каскад продолжится
    }
    if (settings.autoAssignPicker && !order.picker_user_id && ['confirmed', 'packing'].includes(order.status)) {
      await autoAssignPicker(order);
    }
    if (settings.autoAssignDelivery && !order.delivery_user_id && ['packing', 'transit'].includes(order.status)) {
      await autoAssignDelivery(order);
    }
    if (settings.autoComplete && order.status === 'delivered') {
      await autoComplete(order);
    }
    await resolveErrors(order.id); // прошло без ошибок — снимаем прежние пометки, если были
  } catch (err) {
    console.error(`Automation error (order #${order.id}):`, err.message);
    metrics.automationErrorsTotal.inc({ step: order.status });
    await logError(order.id, order.status, err.message);
  }
}

// Прогон по всем заказам, до которых автоматизация ещё не дотянулась —
// вызывается на старте сервера, при изменении настроек и каждую минуту
// (SWEEP_INTERVAL_MS). Периодичность — это и «догонялка» после рестарта
// сервера (setTimeout'ов не бывает, только эта проверка по delivered_at),
// и retry для шагов, упавших с ошибкой на предыдущем проходе.
async function sweep() {
  const { rows } = await pool.query(
    `SELECT * FROM orders WHERE status = 'pending'
       OR (picker_user_id IS NULL AND status IN ('confirmed','packing'))
       OR (delivery_user_id IS NULL AND status IN ('packing','transit'))
       OR (status = 'delivered' AND delivered_at IS NOT NULL
           AND delivered_at <= NOW() - ($1 || ' minutes')::interval)`,
    [Number(settings.completeAfterMinutes) || 15]
  );
  for (const order of rows) await handleOrder(order);
  return rows.length;
}

async function start() {
  await loadSettings();
  bus.on('order', handleOrder);
  const processed = await sweep();
  console.log(`⚡ Автоматизация запущена (${JSON.stringify(settings)}), обработано заказов: ${processed}`);

  if (sweepTimer) clearInterval(sweepTimer);
  sweepTimer = setInterval(() => {
    sweep().catch((err) => console.error('Automation sweep error:', err.message));
  }, SWEEP_INTERVAL_MS);
}

module.exports = { start, getSettings, saveSettings, loadSettings, sweep, getErrors };
