const router = require('express').Router();
const auth = require('../middleware/auth');
const automation = require('../automation');
const { validateBody } = require('../validate');

const AUTOMATION_SCHEMA = {
  autoConfirm: (v) => v == null || typeof v === 'boolean' || 'boolean болушу керек',
  autoAssignPicker: (v) => v == null || typeof v === 'boolean' || 'boolean болушу керек',
  autoAssignDelivery: (v) => v == null || typeof v === 'boolean' || 'boolean болушу керек',
  autoComplete: (v) => v == null || typeof v === 'boolean' || 'boolean болушу керек',
  completeAfterMinutes: (v) => v == null || (Number.isFinite(Number(v)) && Number(v) >= 1) || 'оң сан болушу керек',
};

// GET /api/settings/automation — текущие настройки автоматизации
router.get('/automation', auth(['admin']), (req, res) => {
  res.json(automation.getSettings());
});

// PUT /api/settings/automation — обновить настройки; включённые правила
// сразу применяются к существующим заказам (sweep внутри saveSettings).
router.put('/automation', auth(['admin']), validateBody(AUTOMATION_SCHEMA), async (req, res) => {
  try {
    const { autoConfirm, autoAssignPicker, autoAssignDelivery, autoComplete, completeAfterMinutes } = req.body;
    const patch = {};
    if (typeof autoConfirm === 'boolean') patch.autoConfirm = autoConfirm;
    if (typeof autoAssignPicker === 'boolean') patch.autoAssignPicker = autoAssignPicker;
    if (typeof autoAssignDelivery === 'boolean') patch.autoAssignDelivery = autoAssignDelivery;
    if (typeof autoComplete === 'boolean') patch.autoComplete = autoComplete;
    if (completeAfterMinutes != null) patch.completeAfterMinutes = Number(completeAfterMinutes);
    const saved = await automation.saveSettings(patch);
    res.json(saved);
  } catch (err) {
    console.error('Save automation settings error:', err.message);
    res.status(500).json({ message: 'Тууралоону сактоо мүмкүн болбоду' });
  }
});

// GET /api/settings/automation-errors — fail-safe: неразрешённые ошибки
// автоматизации за последнее время, чтобы админ видел зависшие заказы.
router.get('/automation-errors', auth(['admin']), async (req, res) => {
  try {
    res.json(await automation.getErrors());
  } catch (err) {
    console.error('Get automation errors error:', err.message);
    res.status(500).json({ message: 'Каталарды алуу мүмкүн болбоду' });
  }
});

module.exports = router;
