const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const bus = require('../events/bus');
const { validateBody, validateIdParam, isNonEmptyString, isPhone } = require('../validate');

const VALID_ROLES = ['admin', 'customer', 'picker', 'delivery'];
const PROFILE_SCHEMA = { name: isNonEmptyString, phone: isPhone };
const ROLE_SCHEMA = { role: (v) => VALID_ROLES.includes(v) || `role: бирөө болушу керек — ${VALID_ROLES.join(', ')}` };

// Get all users (admin)
router.get('/', auth(['admin']), async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, phone, role, address, created_at FROM users ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (err) {
    console.error('Get users error:', err.message);
    res.status(500).json({ message: 'Колдонуучуларды алуу мүмкүн болбоду' });
  }
});

// Get profile
router.get('/profile', auth(), async (req, res) => {
  try {
    const result = await pool.query('SELECT id, name, email, phone, role, address FROM users WHERE id = $1', [req.user.id]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Get profile error:', err.message);
    res.status(500).json({ message: 'Профилди алуу мүмкүн болбоду' });
  }
});

// Update profile
router.put('/profile', auth(), validateBody(PROFILE_SCHEMA), async (req, res) => {
  const { name, phone, address } = req.body;
  try {
    const result = await pool.query(
      'UPDATE users SET name=$1, phone=$2, address=$3 WHERE id=$4 RETURNING id, name, email, phone, role, address',
      [name, phone, address, req.user.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update profile error:', err.message);
    res.status(500).json({ message: 'Профилди жаңыртуу мүмкүн болбоду' });
  }
});

// Order history for one employee (picker or courier) — admin only. Same
// shape/join pattern as GET /orders in routes/orders.js, just filtered to
// one employee across both roles instead of returning every order.
router.get('/:id/orders', auth(['admin']), validateIdParam, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT o.*, u.name as customer_name, u.phone as customer_phone,
       json_agg(json_build_object('product_id', oi.product_id, 'quantity', oi.quantity, 'price', oi.price, 'name', p.name)) as items
       FROM orders o
       LEFT JOIN users u ON o.user_id = u.id
       LEFT JOIN order_items oi ON o.id = oi.order_id
       LEFT JOIN products p ON oi.product_id = p.id
       WHERE o.picker_user_id = $1 OR o.delivery_user_id = $1
       GROUP BY o.id, u.name, u.phone ORDER BY o.created_at DESC LIMIT 200`,
      [req.params.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get employee orders error:', err.message);
    res.status(500).json({ message: 'Заказдарды алуу мүмкүн болбоду' });
  }
});

// Update user role (admin). Role is validated against the fixed enum above —
// an admin can't accidentally (or via a bad client) set role to an arbitrary
// string that then silently fails every auth(['picker'/...]) check downstream.
router.patch('/:id/role', auth(['admin']), validateIdParam, validateBody(ROLE_SCHEMA), async (req, res) => {
  const { role } = req.body;
  try {
    const result = await pool.query('UPDATE users SET role=$1 WHERE id=$2 RETURNING id, name, email, role', [role, req.params.id]);
    if (!result.rows[0]) return res.status(404).json({ message: 'Колдонуучу табылган жок' });
    bus.emit('user', result.rows[0]);
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update role error:', err.message);
    res.status(500).json({ message: 'Ролду жаңыртуу мүмкүн болбоду' });
  }
});

module.exports = router;
