const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const pool = require('../config/database');
const bus = require('../events/bus');
const { validateBody, isNonEmptyString, isEmail, isPhone } = require('../validate');

const googleClient = new OAuth2Client(process.env.GOOGLE_WEB_CLIENT_ID);
const BCRYPT_COST = 10;
const MIN_PASSWORD_LENGTH = 8;
const JWT_EXPIRY = '7d';

const REGISTER_SCHEMA = {
  name: isNonEmptyString,
  email: isEmail,
  phone: isPhone,
  password: (v) => (typeof v === 'string' && v.length >= MIN_PASSWORD_LENGTH) ||
    `кеминде ${MIN_PASSWORD_LENGTH} белги болушу керек`,
  // Каттоодо дарек көрсөтүү милдеттүү эмес (карта менен тандоо же кийин
  // кошуу да болот) — ошондуктан null/бош уруксат берилет.
  address: (v) => v == null || v === '' || (typeof v === 'string' && v.length <= 2000) || 'жараксыз дарек',
};
const LOGIN_SCHEMA = {
  email: isEmail,
  password: isNonEmptyString,
};

// Register
router.post('/register', validateBody(REGISTER_SCHEMA), async (req, res) => {
  const { name, email, phone, password, address } = req.body;
  try {
    const hashed = await bcrypt.hash(password, BCRYPT_COST);
    const result = await pool.query(
      'INSERT INTO users (name, email, phone, password, address) VALUES ($1,$2,$3,$4,$5) RETURNING id, name, email, role',
      [name, email, phone, hashed, address]
    );
    const user = result.rows[0];
    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: JWT_EXPIRY });
    bus.emit('user', user); // Dashboard: people counts update live, no manual refresh
    res.status(201).json({ user, token });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ message: 'Этот email уже зарегистрирован' });
    console.error('Register error:', err.message);
    res.status(500).json({ message: 'Катталуу мүмкүн болбоду' });
  }
});

// Login. Both failure modes (unknown email, wrong password) return the same
// generic message — telling them apart lets an attacker enumerate which
// emails have accounts (OWASP A07).
router.post('/login', validateBody(LOGIN_SCHEMA), async (req, res) => {
  const { email, password } = req.body;
  const genericError = { message: 'Email же сырсөз туура эмес' };
  try {
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];
    if (!user) return res.status(401).json(genericError);

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) return res.status(401).json(genericError);

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: JWT_EXPIRY });
    const { password: _, ...userWithoutPassword } = user;
    res.json({ user: userWithoutPassword, token });
  } catch (err) {
    console.error('Login error:', err.message);
    res.status(500).json({ message: 'Кирүү мүмкүн болбоду' });
  }
});

// Google Sign-In: verifies the ID token from the app, then finds or
// creates a customer account by email (Google emails are pre-verified).
router.post('/google', async (req, res) => {
  const { idToken } = req.body;
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_WEB_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const email = payload.email;
    const name = payload.name || email.split('@')[0];

    let result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let user = result.rows[0];

    if (!user) {
      const randomPassword = await bcrypt.hash(require('crypto').randomUUID(), BCRYPT_COST);
      const inserted = await pool.query(
        'INSERT INTO users (name, email, password) VALUES ($1,$2,$3) RETURNING id, name, email, role',
        [name, email, randomPassword]
      );
      user = inserted.rows[0];
      bus.emit('user', user);
    }

    const token = jwt.sign({ id: user.id, role: user.role }, process.env.JWT_SECRET, { expiresIn: JWT_EXPIRY });
    const { password: _, ...userWithoutPassword } = user;
    res.json({ user: userWithoutPassword, token });
  } catch (err) {
    console.error('Google Sign-In error:', err.message);
    res.status(401).json({ message: 'Google аркылуу кирүү мүмкүн болбоду' });
  }
});

module.exports = router;
