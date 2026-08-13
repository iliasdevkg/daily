const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { isIdParam } = require('../validate');

// validateIdParam (validate.js) only checks req.params.id — these routes key
// off :productId instead, so a local twin instead of misusing that one.
function validateProductIdParam(req, res, next) {
  if (!isIdParam(req.params.productId)) {
    return res.status(400).json({ message: 'Жараксыз идентификатор' });
  }
  next();
}

// My liked products, joined with current product info (name/price/image) so
// the app doesn't need a second round-trip — same shape as GET /products.
router.get('/my', auth(), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT f.id as favorite_id, f.created_at as liked_at, p.*
       FROM favorites f JOIN products p ON f.product_id = p.id
       WHERE f.user_id = $1 AND p.is_active = true
       ORDER BY f.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get favorites error:', err.message);
    res.status(500).json({ message: 'Тандалмаларды алуу мүмкүн болбоду' });
  }
});

// Like a product (idempotent — liking twice is a no-op, not an error).
router.post('/:productId', auth(), validateProductIdParam, async (req, res) => {
  try {
    await pool.query(
      'INSERT INTO favorites (user_id, product_id) VALUES ($1,$2) ON CONFLICT (user_id, product_id) DO NOTHING',
      [req.user.id, req.params.productId]
    );
    res.status(201).json({ message: 'Кошулду' });
  } catch (err) {
    console.error('Add favorite error:', err.message);
    res.status(500).json({ message: 'Кошуу мүмкүн болбоду' });
  }
});

// Unlike a product.
router.delete('/:productId', auth(), validateProductIdParam, async (req, res) => {
  try {
    await pool.query('DELETE FROM favorites WHERE user_id=$1 AND product_id=$2', [req.user.id, req.params.productId]);
    res.json({ message: 'Өчүрүлдү' });
  } catch (err) {
    console.error('Remove favorite error:', err.message);
    res.status(500).json({ message: 'Өчүрүү мүмкүн болбоду' });
  }
});

module.exports = router;
