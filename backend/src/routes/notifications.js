const router = require('express').Router();
const pool = require('../config/database');
const auth = require('../middleware/auth');
const { validateIdParam } = require('../validate');

// My notifications (any authenticated role, but only customer role gets
// any written to it currently — see notifications.js).
router.get('/my', auth(), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Get notifications error:', err.message);
    res.status(500).json({ message: 'Билдирмелерди алуу мүмкүн болбоду' });
  }
});

router.patch('/:id/read', auth(), validateIdParam, async (req, res) => {
  try {
    const result = await pool.query(
      'UPDATE notifications SET read = true WHERE id = $1 AND user_id = $2 RETURNING *',
      [req.params.id, req.user.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Билдирме табылган жок' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Mark notification read error:', err.message);
    res.status(500).json({ message: 'Белгилөө мүмкүн болбоду' });
  }
});

module.exports = router;
