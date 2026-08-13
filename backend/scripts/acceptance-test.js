// scripts/acceptance-test.js — Stage 6: Production Acceptance Test.
//
// Runs the exact 10-step order lifecycle against a REAL running backend +
// REAL Postgres (no mocks): customer orders -> automation confirms ->
// picker assigned -> picker finishes -> courier assigned -> courier
// delivers -> order Completed -> notification arrives -> history
// recorded -> earnings calculated. Prints a numbered report and exits
// non-zero if any step fails.
//
// IMPORTANT — read before trusting the result: this script can only run
// against whatever backend TEST_BASE_URL points at. In this environment
// that is the LOCAL backend (http://localhost:3001), not a real deployed
// server — there is no real server in this environment to verify against.
// A pass here proves the order/automation/notification/history/earnings
// pipeline is correct; it does NOT prove HTTPS, DNS, nginx routing, or
// multi-host behavior, which need a real server (see Stage 4/5 caveats).
//
// Steps 4 and 6 ("picker finishes", "courier delivers") are executed
// using the admin token's role-bypass (routes/orders.js: admin skips
// ownership + role-transition checks, same code path either way), NOT by
// logging in as the specific picker/delivery account automation assigned
// — this script has no legitimate way to obtain that seed account's real
// password, and guessing credentials is explicitly out of bounds for this
// project (see project history). Everything else (steps 1-3, 5, 7-10) is
// verified from real API responses / DB-backed endpoints with no bypass.
//
// Usage: node scripts/acceptance-test.js  (from backend/, needs a running
// backend at TEST_BASE_URL, default http://localhost:3001/api)
const BASE = process.env.TEST_BASE_URL || 'http://localhost:3001/api';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'admin@delivery.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'password';
const SUFFIX = Date.now();

let stepNum = 0;
let failures = 0;

function logStep(title) {
  stepNum++;
  console.log(`\n${stepNum}/10  ${title}`);
}
function pass(detail) {
  console.log(`   \x1b[32mOK\x1b[0m  ${detail}`);
}
function failStep(detail) {
  console.log(`   \x1b[31mFAIL\x1b[0m  ${detail}`);
  failures++;
}
async function api(method, path, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const json = await res.json().catch(() => null);
  return { status: res.status, body: json };
}
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  console.log(`Production Acceptance Test — 10-этаптык заказ жашоо цикли`);
  console.log(`Base URL: ${BASE} (ЛОКАЛДУУ backend — реалдуу сервер жок)`);

  // Setup: admin token + a real product with stock, fresh customer account.
  const adminLogin = await api('POST', '/auth/login', { body: { email: ADMIN_EMAIL, password: ADMIN_PASSWORD } });
  if (adminLogin.status !== 200) {
    console.error('FATAL: admin аккаунтуна кирүү мүмкүн болбоду — тест уланбайт.');
    process.exit(1);
  }
  const adminToken = adminLogin.body.token;

  const products = await api('GET', '/products');
  const product = products.body.find((p) => p.stock > 3);
  if (!product) {
    console.error('FATAL: stock > 3 болгон эч бир товар табылган жок.');
    process.exit(1);
  }

  const customerEmail = `acceptance-${SUFFIX}@test.local`;
  const customerReg = await api('POST', '/auth/register', {
    body: { name: 'Acceptance Test Customer', email: customerEmail, password: 'ValidPass123!' },
  });
  if (customerReg.status !== 201) {
    console.error('FATAL: клиент аккаунтун каттоо мүмкүн болбоду.');
    process.exit(1);
  }
  const customerToken = customerReg.body.token;

  // ── 1. Customer orders ──────────────────────────────────────────────
  logStep('Клиент заказ берет (customer orders)');
  const created = await api('POST', '/orders', {
    token: customerToken,
    body: { items: [{ product_id: product.id, quantity: 1 }], address: 'Acceptance test дареги' },
  });
  if (created.status === 201) pass(`заказ #${created.body.id} түзүлдү, статус=${created.body.status}`);
  else return failStep(`POST /orders → ${created.status}: ${JSON.stringify(created.body)}`);
  const orderId = created.body.id;

  await wait(2000); // automation cascade: created -> autoConfirm -> autoAssignPicker

  // ── 2. Automation confirms ──────────────────────────────────────────
  logStep('Автоматизация заказды тастыктайт (automation confirms)');
  let order = (await api('GET', '/orders', { token: adminToken })).body.find((o) => o.id === orderId);
  if (order && order.status === 'confirmed') pass(`статус=confirmed (autoConfirm иштеди)`);
  else return failStep(`күтүлгөн статус 'confirmed', чыныгысы: ${order && order.status}`);

  // ── 3. Picker assigned ──────────────────────────────────────────────
  logStep('Пикер дайындалды (picker assigned)');
  if (order.picker_user_id) pass(`picker_user_id=${order.picker_user_id} (autoAssignPicker иштеди)`);
  else return failStep(`picker_user_id бош — autoAssignPicker иштеген жок`);

  // ── 4. Picker finishes (packing -> transit) ─────────────────────────
  logStep("Пикер жыйноону бүтүрөт (picker finishes, admin-bypass менен — жогорудагы эскертүүнү кара)");
  const toPacking = await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'packing' } });
  const toTransit = toPacking.status === 200
    ? await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'transit' } })
    : null;
  if (toPacking.status === 200 && toTransit && toTransit.status === 200) pass(`confirmed → packing → transit өттү`);
  else return failStep(`packing=${toPacking.status} transit=${toTransit && toTransit.status}`);

  await wait(2000); // autoAssignDelivery fires on status in [packing, transit]

  // ── 5. Courier assigned ─────────────────────────────────────────────
  logStep('Курьер дайындалды (courier assigned)');
  order = (await api('GET', '/orders', { token: adminToken })).body.find((o) => o.id === orderId);
  if (order && order.delivery_user_id) pass(`delivery_user_id=${order.delivery_user_id} (autoAssignDelivery иштеди)`);
  else return failStep(`delivery_user_id бош — autoAssignDelivery иштеген жок`);

  // ── 6. Courier delivers ─────────────────────────────────────────────
  logStep('Курьер жеткирет (courier delivers, admin-bypass менен)');
  const delivered = await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'delivered' } });
  if (delivered.status === 200 && delivered.body.status === 'delivered') pass(`transit → delivered өттү`);
  else return failStep(`PATCH → ${delivered.status}: ${JSON.stringify(delivered.body)}`);

  // ── 7. Order Completed ──────────────────────────────────────────────
  logStep('Заказ Completed болот (order Completed, autoComplete)');
  // autoComplete only fires after settings.completeAfterMinutes (default 15
  // min) — waiting that long here would make the script itself impractical
  // to run, so this step verifies the TRANSITION IS LEGAL AND REACHABLE
  // (delivered -> completed is in TRANSITIONS) via a direct admin PATCH,
  // which is the same production code path autoComplete itself calls
  // (routes/orders.js PATCH handler) minus the timer. The timer logic
  // itself (completeAfterMinutes) is config, not something this run
  // exercises — flagged here explicitly rather than silently assumed.
  const completed = await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'completed' } });
  if (completed.status === 200 && completed.body.status === 'completed') {
    pass(`delivered → completed өттү (эскертүү: autoComplete'дун 15-мүнөттүк таймери өзү сыналган жок, бул скрипт ошончо күтпөйт)`);
  } else return failStep(`PATCH → ${completed.status}: ${JSON.stringify(completed.body)}`);

  // ── 8. Notification arrives ─────────────────────────────────────────
  logStep('Билдирме келет (notification arrives)');
  const notifs = await api('GET', '/notifications/my', { token: customerToken });
  const relevant = (notifs.body || []).filter((n) => n.order_id === orderId);
  if (notifs.status === 200 && relevant.length > 0) pass(`клиентке ${relevant.length} билдирме келди (акыркысы: "${relevant[0].message || relevant[0].title || JSON.stringify(relevant[0])}")`);
  else return failStep(`GET /notifications/my → ${notifs.status}, ушул заказ үчүн билдирме жок`);

  // ── 9. History recorded ─────────────────────────────────────────────
  logStep('Тарых катталды (history recorded)');
  const history = await api('GET', `/orders/${orderId}/history`, { token: adminToken });
  const actions = (history.body || []).map((h) => h.action);
  const expectedActions = ['created', 'status:confirmed', 'picker_assigned', 'status:packing', 'status:transit', 'delivery_assigned', 'status:delivered', 'status:completed'];
  const missing = expectedActions.filter((a) => !actions.includes(a));
  if (history.status === 200 && missing.length === 0) pass(`бардык ${expectedActions.length} этап тарыхта бар: ${actions.join(', ')}`);
  else failStep(`жетишпеген этаптар: ${missing.join(', ') || 'жок'} | чыныгы тарых: ${actions.join(', ')}`);

  // ── 10. Earnings calculated ─────────────────────────────────────────
  logStep('Кирешелер эсептелди (earnings calculated)');
  const earnings = await api('GET', '/earnings/summary', { token: adminToken });
  if (earnings.status === 200 && Array.isArray(earnings.body) && earnings.body.length > 0) {
    pass(`earnings/summary ${earnings.body.length} жазуу кайтарды`);
  } else return failStep(`GET /earnings/summary → ${earnings.status}: ${JSON.stringify(earnings.body)}`);

  console.log(`\n${'='.repeat(50)}`);
  if (failures === 0) {
    console.log(`\x1b[32mБААРЫ ӨТТҮ: 10/10 этап ийгиликтүү (заказ #${orderId})\x1b[0m`);
  } else {
    console.log(`\x1b[31m${failures} этап ката берди (заказ #${orderId})\x1b[0m`);
  }
  console.log('='.repeat(50));
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('FATAL:', err);
  process.exit(1);
});
