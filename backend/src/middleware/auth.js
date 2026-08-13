const jwt = require('jsonwebtoken');

const auth = (roles = []) => (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'Токен отсутствует' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (roles.length && !roles.includes(decoded.role)) {
      return res.status(403).json({ message: 'Доступ запрещён' });
    }
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ message: 'Недействительный токен' });
  }
};

module.exports = auth;
