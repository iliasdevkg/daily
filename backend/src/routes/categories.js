const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { validateBody, validateIdParam, isNonEmptyString } = require('../validate');

const CATEGORY_SCHEMA = { name: isNonEmptyString };

router.get('/', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM categories ORDER BY name');
    res.json(result.rows);
  } catch (err) {
    console.error('Get categories error:', err.message);
    res.status(500).json({ message: 'Категорияларды алуу мүмкүн болбоду' });
  }
});

router.post('/', auth(['admin']), validateBody(CATEGORY_SCHEMA), async (req, res) => {
  const { name, image_url } = req.body;
  try {
    const result = await pool.query('INSERT INTO categories (name, image_url) VALUES ($1,$2) RETURNING *', [name, image_url]);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Create category error:', err.message);
    res.status(500).json({ message: 'Категорияны түзүү мүмкүн болбоду' });
  }
});

router.put('/:id', auth(['admin']), validateIdParam, validateBody(CATEGORY_SCHEMA), async (req, res) => {
  const { name, image_url } = req.body;
  try {
    const result = await pool.query('UPDATE categories SET name=$1, image_url=$2 WHERE id=$3 RETURNING *', [name, image_url, req.params.id]);
    if (!result.rows[0]) return res.status(404).json({ message: 'Категория табылган жок' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update category error:', err.message);
    res.status(500).json({ message: 'Категорияны жаңыртуу мүмкүн болбоду' });
  }
});

router.delete('/:id', auth(['admin']), validateIdParam, async (req, res) => {
  try {
    await pool.query('DELETE FROM categories WHERE id = $1', [req.params.id]);
    res.json({ message: 'Категория удалена' });
  } catch (err) {
    console.error('Delete category error:', err.message);
    res.status(500).json({ message: 'Категорияны өчүрүү мүмкүн болбоду' });
  }
});

module.exports = router;
