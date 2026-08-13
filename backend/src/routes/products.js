const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { validateBody, validateIdParam, isNonEmptyString, isNonNegativeNumber, isPositiveInt } = require('../validate');

const PRODUCT_SCHEMA = {
  name: isNonEmptyString,
  price: isNonNegativeNumber,
  stock: (v) => Number.isInteger(v) && v >= 0 || 'бүтүн, терс эмес сан болушу керек',
  category_id: (v) => v == null || isPositiveInt(v) || 'жараксыз category_id',
  min_stock: (v) => v == null || (Number.isInteger(v) && v >= 0) || 'бүтүн, терс эмес сан болушу керек',
};

// Get all products
router.get('/', async (req, res) => {
  try {
    const { category_id, search } = req.query;
    let query = 'SELECT p.*, c.name as category_name FROM products p LEFT JOIN categories c ON p.category_id = c.id WHERE p.is_active = true';
    const params = [];

    if (category_id) { params.push(category_id); query += ` AND p.category_id = $${params.length}`; }
    if (search) { params.push(`%${search}%`); query += ` AND p.name ILIKE $${params.length}`; }

    query += ' ORDER BY p.created_at DESC';
    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Get products error:', err.message);
    res.status(500).json({ message: 'Товарларды алуу мүмкүн болбоду' });
  }
});

// Закуп: products at or below their own reorder threshold (admin only).
// MUST come before GET /:id — otherwise Express matches "low-stock" as the
// :id param and this route is never reached.
router.get('/low-stock', auth(['admin']), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT p.*, c.name as category_name FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE p.is_active = true AND p.stock <= p.min_stock
       ORDER BY (p.stock - p.min_stock) ASC, p.stock ASC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get low-stock products error:', err.message);
    res.status(500).json({ message: 'Товарларды алуу мүмкүн болбоду' });
  }
});

// Get single product
router.get('/:id', validateIdParam, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT p.*, c.name as category_name FROM products p LEFT JOIN categories c ON p.category_id = c.id WHERE p.id = $1',
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Товар не найден' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Get product error:', err.message);
    res.status(500).json({ message: 'Товарды алуу мүмкүн болбоду' });
  }
});

// Create product (admin only)
router.post('/', auth(['admin']), validateBody(PRODUCT_SCHEMA), async (req, res) => {
  const { name, description, price, stock, image_url, category_id, min_stock } = req.body;
  try {
    const result = await pool.query(
      'INSERT INTO products (name, description, price, stock, image_url, category_id, min_stock) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *',
      [name, description, price, stock, image_url, category_id, min_stock ?? 5]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Create product error:', err.message);
    res.status(500).json({ message: 'Товарды түзүү мүмкүн болбоду' });
  }
});

// Update product (admin only)
router.put('/:id', auth(['admin']), validateIdParam, validateBody(PRODUCT_SCHEMA), async (req, res) => {
  const { name, description, price, stock, image_url, category_id, is_active, min_stock } = req.body;
  try {
    const result = await pool.query(
      'UPDATE products SET name=$1, description=$2, price=$3, stock=$4, image_url=$5, category_id=$6, is_active=$7, min_stock=$8 WHERE id=$9 RETURNING *',
      [name, description, price, stock, image_url, category_id, is_active, min_stock ?? 5, req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Товар не найден' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update product error:', err.message);
    res.status(500).json({ message: 'Товарды жаңыртуу мүмкүн болбоду' });
  }
});

// Delete product (admin only) — soft delete, matches order_items keeping a
// historical reference to products that are no longer for sale.
router.delete('/:id', auth(['admin']), validateIdParam, async (req, res) => {
  try {
    await pool.query('UPDATE products SET is_active = false WHERE id = $1', [req.params.id]);
    res.json({ message: 'Товар удалён' });
  } catch (err) {
    console.error('Delete product error:', err.message);
    res.status(500).json({ message: 'Товарды өчүрүү мүмкүн болбоду' });
  }
});

module.exports = router;
