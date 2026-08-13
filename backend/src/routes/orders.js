const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const bus = require('../events/bus');
const { isValidTransition, roleCanSetStatus, ownsOrder } = require('../orderStateMachine');
const { validateBody, validateIdParam, isNonEmptyString, isPositiveInt, isNonEmptyArray } = require('../validate');
const metrics = require('../metrics');

const ORDER_ITEMS_SCHEMA = {
  items: (v) => isNonEmptyArray(v) && v.every((i) =>
    i && typeof i === 'object' && isPositiveInt(i.product_id) && isPositiveInt(i.quantity)
  ) || 'items: непустой массив { product_id, quantity } (целые положительные числа)',
  address: isNonEmptyString,
};

// Create order (customer). The client sends only product_id + quantity —
// price, subtotal and total are never trusted from the request: they are
// always derived from products.price at the moment of purchase, inside the
// same row-locked transaction that checks and decrements stock. Any
// total/subtotal/price the client sends is silently ignored.
router.post('/', auth(['customer', 'admin']), validateBody(ORDER_ITEMS_SCHEMA), async (req, res) => {
  const { items, address, note } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Stock + price guard: lock the rows so two concurrent orders can't
    // both pass the check for the last unit, then refuse the whole order
    // (not a partial one) if anything is short — the customer sees exactly
    // which product ran out instead of a generic failure. price/stock come
    // from this row, never from the request body.
    const productIds = items.map((i) => i.product_id);
    const { rows: products } = await client.query(
      'SELECT id, name, price, stock FROM products WHERE id = ANY($1) FOR UPDATE',
      [productIds]
    );
    for (const item of items) {
      const product = products.find((p) => p.id === item.product_id);
      if (!product || product.stock < item.quantity) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          message: product
            ? `«${product.name}» жетишсиз калды: складда ${product.stock} даана, ${item.quantity} суралды`
            : 'Товар табылган жок',
        });
      }
    }

    const total = items.reduce((sum, i) => {
      const product = products.find((p) => p.id === i.product_id);
      return sum + Number(product.price) * i.quantity;
    }, 0);
    const orderResult = await client.query(
      'INSERT INTO orders (user_id, total, address, note) VALUES ($1,$2,$3,$4) RETURNING *',
      [req.user.id, total, address, note]
    );
    const order = orderResult.rows[0];
    for (const item of items) {
      const product = products.find((p) => p.id === item.product_id);
      await client.query(
        'INSERT INTO order_items (order_id, product_id, quantity, price) VALUES ($1,$2,$3,$4)',
        [order.id, item.product_id, item.quantity, product.price]
      );
      await client.query('UPDATE products SET stock = stock - $1 WHERE id = $2', [item.quantity, item.product_id]);
    }
    await client.query('COMMIT');
    metrics.ordersCreatedTotal.inc();
    bus.emit('order', order, 'created'); // SSE + automation + notifications + history all key off this
    res.status(201).json(order);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Order creation error:', err.message);
    res.status(500).json({ message: 'Заказды түзүү мүмкүн болбоду' });
  } finally {
    client.release();
  }
});

// Get my orders (customer)
router.get('/my', auth(['customer']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT o.*, json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name, 'image_url', p.image_url)) as items
       FROM orders o LEFT JOIN order_items oi ON o.id = oi.order_id LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.user_id = $1 GROUP BY o.id ORDER BY o.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get my orders error:', err.message);
    res.status(500).json({ message: 'Заказдарды алуу мүмкүн болбоду' });
  }
});

// Get all orders (admin). limit is capped at 500 regardless of what's
// requested — same shape as before (a plain array) so admin-web's existing
// api.getOrders() keeps working unchanged; it just stops being able to pull
// an unbounded number of rows in one response as the table grows.
router.get('/', auth(['admin']), async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 500, 500);
    const offset = Math.max(Number(req.query.offset) || 0, 0);
    const result = await pool.query(
      `SELECT o.*, u.name as customer_name, u.phone as customer_phone,
       d.name as delivery_name, pk.name as picker_name,
       json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name, 'image_url', p.image_url)) as items
       FROM orders o
       LEFT JOIN users u ON o.user_id = u.id
       LEFT JOIN users d ON o.delivery_user_id = d.id
       LEFT JOIN users pk ON o.picker_user_id = pk.id
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       GROUP BY o.id, u.name, u.phone, d.name, pk.name ORDER BY o.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get all orders error:', err.message);
    res.status(500).json({ message: 'Заказдарды алуу мүмкүн болбоду' });
  }
});

// Get picker orders (сборщик — собирает подтверждённые заказы)
router.get('/picker', auth(['picker', 'admin']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT o.*, u.name as customer_name, u.phone as customer_phone,
       json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name, 'image_url', p.image_url)) as items
       FROM orders o
       LEFT JOIN users u ON o.user_id = u.id
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.status IN ('confirmed','packing') OR o.picker_user_id = $1
       GROUP BY o.id, u.name, u.phone ORDER BY o.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get picker orders error:', err.message);
    res.status(500).json({ message: 'Заказдарды алуу мүмкүн болбоду' });
  }
});

// Get delivery orders (доставщик — доставляет заказы в пути)
router.get('/delivery', auth(['delivery', 'admin']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT o.*, u.name as customer_name, u.phone as customer_phone,
       json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name)) as items
       FROM orders o
       LEFT JOIN users u ON o.user_id = u.id
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.delivery_user_id = $1 OR (o.status = 'transit' AND o.delivery_user_id IS NULL)
       GROUP BY o.id, u.name, u.phone ORDER BY o.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get delivery orders error:', err.message);
    res.status(500).json({ message: 'Заказдарды алуу мүмкүн болбоду' });
  }
});

// Update order status (admin | delivery | picker)
//
// Permission matrix (enforced below, not just documented):
//   admin    — any order, any legal transition (state machine still applies —
//              even admin can't jump e.g. completed -> confirmed).
//   picker   — only an order that is unclaimed or already assigned to them;
//              may only drive it to 'packing' (claim) or 'transit' (handoff).
//   delivery — only an order that is unclaimed or already assigned to them;
//              may only drive it to 'delivered'; may also "claim" a transit
//              order (delivery_user_id set, status unchanged) with no status
//              change requested.
//   customer — no access to this route at all (not in the auth() list).
//
// A single call can change status AND assign a picker/courier at once (the
// admin "assign + save" modal does exactly that), so this emits one tagged
// 'order' event per thing that actually changed rather than one generic
// event — automation.js, notifications.js and history.js each key off the
// action string, and a no-op field (unchanged) never fires its event.
router.patch('/:id/status', auth(['admin', 'delivery', 'picker']), validateIdParam, async (req, res) => {
  const { status, delivery_user_id, picker_user_id } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: beforeRows } = await client.query('SELECT * FROM orders WHERE id = $1 FOR UPDATE', [req.params.id]);
    const before = beforeRows[0];
    if (!before) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Заказ табылган жок' });
    }

    // Ownership: admin bypasses, picker/delivery may only touch an order
    // that is unclaimed or already theirs (orderStateMachine.ownsOrder).
    if (req.user.role !== 'admin' && !ownsOrder(req.user.role, before, req.user.id)) {
      await client.query('ROLLBACK');
      return res.status(403).json({ message: 'Бул сиздин заказыңыз эмес' });
    }

    const nextStatus = status || before.status;
    const statusChanging = nextStatus !== before.status;

    if (statusChanging) {
      if (!isValidTransition(before.status, nextStatus)) {
        await client.query('ROLLBACK');
        return res.status(400).json({ message: `«${before.status}» → «${nextStatus}» өтүшү мыйзамсыз` });
      }
      if (req.user.role !== 'admin' && !roleCanSetStatus(req.user.role, nextStatus)) {
        await client.query('ROLLBACK');
        return res.status(403).json({ message: 'Бул статуска өтүүгө уруксатыңыз жок' });
      }
    }

    const deliveredAt = nextStatus === 'delivered' && before.status !== 'delivered' ? 'NOW()' : 'delivered_at';
    const result = await client.query(
      `UPDATE orders
       SET status=$1,
           delivery_user_id=COALESCE($2, delivery_user_id),
           picker_user_id=COALESCE($3, picker_user_id),
           delivered_at=${deliveredAt}
       WHERE id=$4 RETURNING *`,
      [nextStatus, delivery_user_id || null, picker_user_id || null, req.params.id]
    );
    await client.query('COMMIT');

    const updated = result.rows[0];
    if (before.picker_user_id == null && updated.picker_user_id != null) {
      bus.emit('order', updated, 'picker_assigned');
    }
    if (before.delivery_user_id == null && updated.delivery_user_id != null) {
      bus.emit('order', updated, 'delivery_assigned');
    }
    if (before.status !== updated.status) {
      bus.emit('order', updated, `status:${updated.status}`);
    }
    res.json(updated);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Order status update error:', err.message);
    res.status(500).json({ message: 'Статусту өзгөртүү мүмкүн болбоду' });
  } finally {
    client.release();
  }
});

// Audit trail for one order (admin, or the customer who placed it).
router.get('/:id/history', auth(), validateIdParam, async (req, res) => {
  try {
    const { rows: orderRows } = await pool.query('SELECT user_id FROM orders WHERE id = $1', [req.params.id]);
    if (!orderRows[0]) return res.status(404).json({ message: 'Заказ табылган жок' });
    if (req.user.role !== 'admin' && orderRows[0].user_id !== req.user.id) {
      return res.status(403).json({ message: 'Доступ запрещён' });
    }
    const result = await pool.query(
      `SELECT h.*, u.name as actor_name FROM order_history h
       LEFT JOIN users u ON h.actor_user_id = u.id
       WHERE h.order_id = $1 ORDER BY h.created_at ASC`,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get order history error:', err.message);
    res.status(500).json({ message: 'Тарыхты алуу мүмкүн болбоду' });
  }
});

module.exports = router;
