// Лёгкая, без внешней зависимости валидация body/query/params. Не Joi/Zod —
// сознательный выбор: набор проверок здесь маленький и стабильный, а
// добавлять тяжёлую библиотеку ради десятка правил — лишняя связанность
// ради абстракции, которая не нужна на этом масштабе.

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_RE = /^\+?[0-9]{7,15}$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const isNonEmptyString = (v) => typeof v === 'string' && v.trim().length > 0 && v.length <= 2000;
const isEmail = (v) => typeof v === 'string' && v.length <= 254 && EMAIL_RE.test(v);
const isPhone = (v) => v == null || v === '' || (typeof v === 'string' && PHONE_RE.test(v));
const isUUID = (v) => typeof v === 'string' && UUID_RE.test(v);
const isPositiveInt = (v) => Number.isInteger(v) && v > 0;
const isNonNegativeNumber = (v) => typeof v === 'number' && Number.isFinite(v) && v >= 0;
const isNonEmptyArray = (v) => Array.isArray(v) && v.length > 0 && v.length <= 200; // 200: sane cap on items-per-order
const isIdParam = (v) => /^[1-9][0-9]*$/.test(String(v)); // SERIAL PK — positive integer string

// schema: { fieldName: validatorFn | (value) => true | 'error message' }.
// A validator returning a string is treated as the error message for that
// field; returning falsy uses a generic "invalid" message.
function validateBody(schema) {
  return (req, res, next) => {
    const errors = [];
    for (const [field, check] of Object.entries(schema)) {
      const value = req.body?.[field];
      const result = check(value);
      if (result === true) continue;
      errors.push(`${field}: ${typeof result === 'string' ? result : 'жараксыз маани'}`);
    }
    if (errors.length) return res.status(400).json({ message: errors.join('; ') });
    next();
  };
}

// For routes keying off req.params.id (SERIAL PK, e.g. /orders/:id).
function validateIdParam(req, res, next) {
  if (!isIdParam(req.params.id)) {
    return res.status(400).json({ message: 'Жараксыз идентификатор' });
  }
  next();
}

module.exports = {
  isNonEmptyString, isEmail, isPhone, isUUID, isPositiveInt, isNonNegativeNumber,
  isNonEmptyArray, isIdParam, validateBody, validateIdParam,
};
