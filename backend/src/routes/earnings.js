const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const earnings = require('../earnings');
const { validateBody } = require('../validate');

const RATES_SCHEMA = {
  pickerFee: (v) => v == null || (Number.isFinite(Number(v)) && Number(v) >= 0) || 'терс эмес сан болушу керек',
  deliveryFee: (v) => v == null || (Number.isFinite(Number(v)) && Number(v) >= 0) || 'терс эмес сан болушу керек',
};

// Own payout history (picker or delivery).
router.get('/my', auth(['picker', 'delivery']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT e.*, o.address, o.total as order_total FROM earnings e
       JOIN orders o ON e.order_id = o.id
       WHERE e.user_id = $1 ORDER BY e.created_at DESC LIMIT 100`,
      [req.user.id]
    );
    const total = result.rows.reduce((s, r) => s + parseFloat(r.amount), 0);
    res.json({ total, entries: result.rows });
  } catch (err) {
    console.error('Get earnings error:', err.message);
    res.status(500).json({ message: 'Кирешени алуу мүмкүн болбоду' });
  }
});

// Admin-wide summary: totals per role plus per-user breakdown, used by the
// Dashboard revenue/payout cards.
router.get('/summary', auth(['admin']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT e.role, u.id as user_id, u.name, SUM(e.amount) as total, COUNT(*) as orders
       FROM earnings e JOIN users u ON e.user_id = u.id
       GROUP BY e.role, u.id, u.name ORDER BY e.role, total DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get earnings summary error:', err.message);
    res.status(500).json({ message: 'Отчётту алуу мүмкүн болбоду' });
  }
});

router.get('/rates', auth(['admin']), (req, res) => {
  res.json(earnings.getRates());
});

router.put('/rates', auth(['admin']), validateBody(RATES_SCHEMA), async (req, res) => {
  try {
    const { pickerFee, deliveryFee } = req.body;
    const patch = {};
    if (pickerFee != null) patch.pickerFee = Number(pickerFee);
    if (deliveryFee != null) patch.deliveryFee = Number(deliveryFee);
    const saved = await earnings.saveRates(patch);
    res.json(saved);
  } catch (err) {
    console.error('Save earnings rates error:', err.message);
    res.status(500).json({ message: 'Тарифти сактоо мүмкүн болбоду' });
  }
});

module.exports = router;
