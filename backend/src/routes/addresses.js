const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { validateBody, validateIdParam, isNonEmptyString } = require('../validate');

const isLatLng = (v) => v == null || (typeof v === 'number' && Number.isFinite(v));

const ADDRESS_SCHEMA = {
  address_text: isNonEmptyString,
  label: (v) => v == null || (typeof v === 'string' && v.length <= 50) || 'кыска ат болушу керек (макс 50 белги)',
  lat: isLatLng,
  lng: isLatLng,
};

// My saved addresses (default first, then newest).
router.get('/my', auth(), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM addresses WHERE user_id = $1 ORDER BY is_default DESC, created_at DESC',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get addresses error:', err.message);
    res.status(500).json({ message: 'Даректерди алуу мүмкүн болбоду' });
  }
});

// Create. First saved address becomes the default automatically — no extra
// step needed for the common case of just having one address.
router.post('/', auth(), validateBody(ADDRESS_SCHEMA), async (req, res) => {
  const { label, address_text, lat, lng, is_default } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: existing } = await client.query('SELECT COUNT(*)::int AS n FROM addresses WHERE user_id = $1', [req.user.id]);
    const makeDefault = is_default === true || existing[0].n === 0;
    if (makeDefault) {
      await client.query('UPDATE addresses SET is_default = false WHERE user_id = $1', [req.user.id]);
    }
    const result = await client.query(
      'INSERT INTO addresses (user_id, label, address_text, lat, lng, is_default) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [req.user.id, label || null, address_text, lat ?? null, lng ?? null, makeDefault]
    );
    await client.query('COMMIT');
    res.status(201).json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Create address error:', err.message);
    res.status(500).json({ message: 'Дарек кошуу мүмкүн болбоду' });
  } finally {
    client.release();
  }
});

// Update (own address only).
router.put('/:id', auth(), validateIdParam, validateBody(ADDRESS_SCHEMA), async (req, res) => {
  const { label, address_text, lat, lng } = req.body;
  try {
    const result = await pool.query(
      'UPDATE addresses SET label=$1, address_text=$2, lat=$3, lng=$4 WHERE id=$5 AND user_id=$6 RETURNING *',
      [label || null, address_text, lat ?? null, lng ?? null, req.params.id, req.user.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Дарек табылган жок' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Update address error:', err.message);
    res.status(500).json({ message: 'Дарек жаңыртуу мүмкүн болбоду' });
  }
});

// Set default (own address only) — unsets any previous default in one txn.
router.patch('/:id/default', auth(), validateIdParam, async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: owned } = await client.query('SELECT id FROM addresses WHERE id=$1 AND user_id=$2', [req.params.id, req.user.id]);
    if (!owned[0]) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Дарек табылган жок' });
    }
    await client.query('UPDATE addresses SET is_default = false WHERE user_id = $1', [req.user.id]);
    const result = await client.query('UPDATE addresses SET is_default = true WHERE id = $1 RETURNING *', [req.params.id]);
    await client.query('COMMIT');
    res.json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Set default address error:', err.message);
    res.status(500).json({ message: 'Дарек белгилөө мүмкүн болбоду' });
  } finally {
    client.release();
  }
});

// Delete (own address only).
router.delete('/:id', auth(), validateIdParam, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM addresses WHERE id=$1 AND user_id=$2 RETURNING id', [req.params.id, req.user.id]);
    if (!result.rows[0]) return res.status(404).json({ message: 'Дарек табылган жок' });
    res.json({ message: 'Дарек өчүрүлдү' });
  } catch (err) {
    console.error('Delete address error:', err.message);
    res.status(500).json({ message: 'Дарек өчүрүү мүмкүн болбоду' });
  }
});

module.exports = router;
