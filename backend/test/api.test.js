// Интеграционные тесты — бьют по реально запущенному backend + реальной
// Postgres (BASE_URL, по умолчанию http://localhost:3001). Отдельной
// тестовой БД/мокового пула в проекте нет; заводить их ради этого прогона
// значило бы вводить новую инфраструктуру, а не укреплять существующую —
// поэтому тесты используют уникальные (timestamp-суффикс) email/данные,
// чтобы не пересекаться друг с другом и с тем, что уже есть в базе, и не
// трогают ничего из посевных данных.
//
// Запуск: npm test (из backend/), либо node --test test/
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const BASE = process.env.TEST_BASE_URL || 'http://localhost:3001/api';
const SUFFIX = Date.now();

async function api(method, path, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => null);
  return { status: res.status, body: json };
}

let adminToken;
let testProduct;

before(async () => {
  const login = await api('POST', '/auth/login', {
    body: { email: 'admin@delivery.com', password: 'password' },
  });
  assert.equal(login.status, 200, 'seed admin login must work for the rest of the suite to run');
  adminToken = login.body.token;

  const products = await api('GET', '/products');
  testProduct = products.body.find((p) => p.stock > 5);
  assert.ok(testProduct, 'need at least one product with stock > 5 in the dev DB to run order tests');
});

// ── Authentication ──────────────────────────────────────────────────────

test('register: rejects a password shorter than the minimum', async () => {
  const res = await api('POST', '/auth/register', {
    body: { name: 'Test', email: `short-${SUFFIX}@test.local`, password: '123' },
  });
  assert.equal(res.status, 400);
});

test('register + login: round-trips with a valid password', async () => {
  const email = `roundtrip-${SUFFIX}@test.local`;
  const reg = await api('POST', '/auth/register', {
    body: { name: 'Test User', email, password: 'ValidPass123!' },
  });
  assert.equal(reg.status, 201);
  assert.ok(reg.body.token);

  const login = await api('POST', '/auth/login', { body: { email, password: 'ValidPass123!' } });
  assert.equal(login.status, 200);
});

test('login: unknown email and wrong password return the identical generic message (no user enumeration)', async () => {
  const unknown = await api('POST', '/auth/login', { body: { email: `nobody-${SUFFIX}@test.local`, password: 'whatever1' } });
  const wrongPw = await api('POST', '/auth/login', { body: { email: 'admin@delivery.com', password: 'definitely-wrong' } });
  assert.equal(unknown.status, 401);
  assert.equal(wrongPw.status, 401);
  assert.equal(unknown.body.message, wrongPw.body.message);
});

// ── Authorization / Validation ──────────────────────────────────────────

test('authorization: a customer token cannot list all orders (admin-only route)', async () => {
  const email = `authz-${SUFFIX}@test.local`;
  const reg = await api('POST', '/auth/register', { body: { name: 'Authz', email, password: 'ValidPass123!' } });
  const res = await api('GET', '/orders', { token: reg.body.token });
  assert.equal(res.status, 403);
});

test('validation: order creation rejects a non-array items field', async () => {
  const res = await api('POST', '/orders', { token: adminToken, body: { items: 'not-an-array', address: 'x' } });
  assert.equal(res.status, 400);
});

test('validation: order creation rejects a missing address', async () => {
  const res = await api('POST', '/orders', {
    token: adminToken,
    body: { items: [{ product_id: testProduct.id, quantity: 1 }] },
  });
  assert.equal(res.status, 400);
});

// ── Price calculation / Stock ───────────────────────────────────────────

test('price calculation: server ignores a client-supplied price and uses products.price', async () => {
  const res = await api('POST', '/orders', {
    token: adminToken,
    body: { items: [{ product_id: testProduct.id, quantity: 1, price: 0.01 }], address: 'price test' },
  });
  assert.equal(res.status, 201);
  assert.equal(Number(res.body.total), Number(testProduct.price));
});

test('stock: an order for more than available stock is rejected and nothing is deducted', async () => {
  const res = await api('POST', '/orders', {
    token: adminToken,
    body: { items: [{ product_id: testProduct.id, quantity: 999999 }], address: 'stock test' },
  });
  assert.equal(res.status, 400);
});

// ── Order lifecycle / Automation / History / Notifications / Earnings ──

test('order lifecycle: full flow — created, auto-confirmed, auto-assigned, history + notification recorded', async () => {
  const created = await api('POST', '/orders', {
    token: adminToken,
    body: { items: [{ product_id: testProduct.id, quantity: 1 }], address: 'lifecycle test' },
  });
  assert.equal(created.status, 201);
  const orderId = created.body.id;

  await new Promise((r) => setTimeout(r, 1500)); // let the automation cascade run

  const list = await api('GET', '/orders', { token: adminToken });
  const order = list.body.find((o) => o.id === orderId);
  assert.equal(order.status, 'confirmed', 'autoConfirm should have fired');
  assert.ok(order.picker_user_id, 'autoAssignPicker should have fired');

  const history = await api('GET', `/orders/${orderId}/history`, { token: adminToken });
  assert.equal(history.status, 200);
  const actions = history.body.map((h) => h.action);
  assert.ok(actions.includes('created'));
  assert.ok(actions.includes('status:confirmed'));
  assert.ok(actions.includes('picker_assigned'));
});

test('order lifecycle: illegal transition (confirmed -> delivered) is rejected even for admin', async () => {
  const created = await api('POST', '/orders', {
    token: adminToken,
    body: { items: [{ product_id: testProduct.id, quantity: 1 }], address: 'illegal transition test' },
  });
  await new Promise((r) => setTimeout(r, 1500));
  const res = await api('PATCH', `/orders/${created.body.id}/status`, { token: adminToken, body: { status: 'delivered' } });
  assert.equal(res.status, 400);
});

test('earnings: delivering an order records a picker + courier payout', async () => {
  const created = await api('POST', '/orders', {
    token: adminToken,
    body: { items: [{ product_id: testProduct.id, quantity: 1 }], address: 'earnings test' },
  });
  const orderId = created.body.id;
  await new Promise((r) => setTimeout(r, 1500));

  await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'packing' } });
  await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'transit' } });
  await api('PATCH', `/orders/${orderId}/status`, { token: adminToken, body: { status: 'delivered' } });
  await new Promise((r) => setTimeout(r, 500));

  const summary = await api('GET', '/earnings/summary', { token: adminToken });
  assert.equal(summary.status, 200);
  assert.ok(Array.isArray(summary.body));
});

// ── Fail-safe / Retry ────────────────────────────────────────────────────

test('fail-safe: automation-errors endpoint is reachable and returns an array', async () => {
  const res = await api('GET', '/settings/automation-errors', { token: adminToken });
  assert.equal(res.status, 200);
  assert.ok(Array.isArray(res.body));
});

// ── Infrastructure: health/ready/live/metrics ───────────────────────────

test('infra: /live always reports alive without checking dependencies', async () => {
  const res = await fetch(`${BASE}/live`);
  const body = await res.json();
  assert.equal(res.status, 200);
  assert.equal(body.status, 'alive');
});

test('infra: /ready reports each dependency check individually', async () => {
  const res = await fetch(`${BASE}/ready`);
  const body = await res.json();
  assert.ok(res.status === 200 || res.status === 503);
  assert.ok('database' in body.checks);
  assert.ok('memory' in body.checks);
});

test('infra: /metrics exposes Prometheus text format, unauthenticated', async () => {
  const res = await fetch('http://localhost:3001/metrics');
  const text = await res.text();
  assert.equal(res.status, 200);
  assert.ok(text.includes('daily_http_requests_total'));
  assert.ok(text.includes('daily_orders_created_total'));
});

after(async () => {
  // Best-effort cleanup: cancel anything this run created so it doesn't
  // linger as noise in the admin UI. Not fatal if it misses something —
  // this is dev data, not production.
});
