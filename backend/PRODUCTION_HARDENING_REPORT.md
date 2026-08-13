# Production Hardening Report

Follow-up to the production readiness audit (score: 39/100). Scope: fix
both Critical findings and as many High/Medium findings as could be done
without adding features, changing UX, changing design, or breaking the
existing architecture — per explicit instruction.

## Files changed

**25 files** — 17 modified, 8 new — all in `backend/`.

| File | Change |
|---|---|
| `src/routes/orders.js` | Critical #1 (price authority) + Critical #2 (permission matrix) + state machine wiring |
| `src/orderStateMachine.js` | **new** — legal status transitions + role/ownership matrix |
| `src/validate.js` | **new** — input validation used across every route |
| `src/migrations.js` | **new** — single ordered schema migration list, replaces 4 duplicated `ensureTable()`s, adds missing indexes |
| `src/automation.js` | `leastBusy()` race fix (advisory lock); schema creation moved to migrations.js |
| `src/config/database.js` | `pool.on('error')`, explicit pool sizing |
| `src/events/bus.js` | `setMaxListeners(0)` |
| `src/app.js` | helmet, compression, rate limiting, request size cap, graceful shutdown, migration runner wiring |
| `src/routes/auth.js` | password length validation, generic login error, JWT/bcrypt constants |
| `src/routes/{products,categories,users}.js` | input validation, no more `err.message` leaked to client |
| `src/{history,notifications,earnings}.js` | schema creation removed (now in migrations.js) |
| `src/routes/{settings,notifications,earnings}.js` | validation, error-message hardening |
| `test/api.test.js` | **new** — 12 integration tests |
| `Dockerfile`, `.dockerignore`, `ecosystem.config.js`, `scripts/backup.sh` | **new** — deployment infra |

## Critical findings — fixed and verified live

### Critical #1 — client-controlled price
`routes/orders.js`: total is now computed from `products.price`, read
inside the same row-locked transaction that checks stock. Verified live:
sent `price: 0.01` for a ⁠80-сом item, server returned `total: "80.00"`.

### Critical #2 — no ownership check on order status changes
`routes/orders.js` + `orderStateMachine.js`: picker/delivery can only
touch an order that is unclaimed or already assigned to them (403
otherwise); every status change is validated against an explicit
transition map (illegal jumps rejected with 400, **including for admin**).
Verified live: a second picker account touching another picker's order →
`403 "Бул сиздин заказыңыз эмес"`; `confirmed → delivered` → `400`.

**Regression caught during verification, not before:** the first version
of the role/transition matrix didn't match picker-app's real behavior —
its "finish collecting" button sends `status: 'transit'`, which the
matrix didn't allow, so the fix as first written would have broken a
working button. Found by testing against the actual app flow rather than
trusting the design, fixed before commit.

## High findings — fixed

- `leastBusy()` race (automation.js): two orders confirmed simultaneously
  could pick the same "least busy" picker/courier — not a double
  assignment (that was already guarded), a fairness bug. Fixed with
  `pg_advisory_xact_lock` per role.
- Missing `pool.on('error')` (database.js): an idle client erroring would
  have crashed the whole process on one network blip.
- No rate limiting anywhere: added a general limiter (1000/15min) and a
  stricter one on `/auth/*` (20/15min). `/api/health` is explicitly
  exempt — an earlier version of this change let a load-test burst trip
  the limiter on the same endpoint Render's uptime probe hits, which
  would have caused false "service down" restarts in production.
- No input validation: added across every route (email/phone format,
  password length, price/stock non-negativity, order item shape, id
  params).
- `err.message` returned to the client on every 500 (leaked Postgres
  internals): now logged server-side, generic message to the client.
- Missing indexes on `orders.user_id/picker_user_id/delivery_user_id/
  status` and `order_items.order_id/product_id`: added via migrations.js.
- `GET /orders` had no bound on result size: capped at 500 rows
  (limit/offset supported, same array response shape).

## Medium/Low findings — fixed

- Login's "user not found" vs "wrong password" unified into one generic
  message (was allowing email enumeration).
- `EventEmitter` default `maxListeners` (10) on the shared bus: raised to
  unlimited — each SSE connection legitimately adds 3 listeners for its
  lifetime, correctly removed on disconnect, but >10 concurrent tabs was
  spamming `MaxListenersExceededWarning`.
- Duplicate `CREATE TABLE settings` (automation.js and earnings.js both
  had it): consolidated into migrations.js.
- Magic numbers (bcrypt cost, JWT expiry, shutdown timeout) extracted to
  named constants.

## Deliberately not done (and why)

- **Stage 7's "everything in one transaction"**: order creation
  (stock + order + order_items) was already correctly transactional. Also
  wrapping history/notification/automation/earnings writes into that same
  transaction would mean a failed notification insert rolls back a paid
  order — worse for the business, not more correct. Instead, each
  downstream consumer (history.js/notifications.js/earnings.js) already
  fails independently and logs rather than crashing; automation.js's
  `sweep()` additionally retries anything that didn't complete.
- **Discount/tax/delivery-fee/bonus pricing** (Stage 3's idealized list):
  this schema has none of those concepts today. Adding them would be new
  product features, out of this task's explicit scope — only
  `products.price` exists, and it is now the sole, server-trusted source.
- **100k+ concurrent virtual users**: not run locally. The machine this
  session runs on hit a full load-average-45 crash earlier today under
  much lighter load than that would require; running a real large-scale
  load generator against it would risk the same outcome for no reliable
  data. Ran a safe empirical check (100 concurrent reads, p95 35ms, load
  average stayed ~2.7) plus the analytical scaling walkthrough from the
  audit — see `PRODUCTION_AUDIT` artifact for the 100 → 4,000,000 table.
- **Real APM/centralized log aggregation**: needs an external service
  account (Sentry/Datadog/etc.), not something addable from code alone.
- **Horizontal scaling** (Redis pub/sub replacing `bus.js`): explicitly
  out of scope — this pass hardens the existing single-instance
  architecture, doesn't replace it. Documented as the top scaling
  priority in the audit.

## Test suite

`npm test` → `node --test test/*.test.js`, integration tests against the
live local instance (no test DB/mocking infra existed; adding one would
be new infrastructure, not hardening). **12/12 passing**, consistently
across three separate runs during this session:

```
✔ register: rejects a password shorter than the minimum
✔ register + login: round-trips with a valid password
✔ login: unknown email and wrong password return the identical generic message
✔ authorization: a customer token cannot list all orders (admin-only route)
✔ validation: order creation rejects a non-array items field
✔ validation: order creation rejects a missing address
✔ price calculation: server ignores a client-supplied price and uses products.price
✔ stock: an order for more than available stock is rejected and nothing is deducted
✔ order lifecycle: full flow — created, auto-confirmed, auto-assigned, history + notification recorded
✔ order lifecycle: illegal transition (confirmed -> delivered) is rejected even for admin
✔ earnings: delivering an order records a picker + courier payout
✔ fail-safe: automation-errors endpoint is reachable and returns an array
```

## Scores — before / after

| Category | Before | After | Why |
|---|---|---|---|
| Security | 28 | **72** | Both criticals fixed, rate limiting, validation, no more error-message leakage, IDOR closed |
| Backend | 52 | **74** | Migration consolidation, graceful shutdown, pool hardening, permission matrix |
| Database | 40 | **68** | Missing indexes added; still no CHECK constraints, no formal migration tool |
| Automation | 74 | **83** | Race condition fixed; retry coverage is still sweep()-shaped, not universal |
| Performance | 35 | **50** | Pagination cap, indexes, compression; still no cache/queue/Redis |
| Architecture | 58 | **64** | DRY'd migrations, extracted state machine module; still no repository/DI layer |
| Scalability | 22 | **26** | Single-instance ceiling untouched on purpose (out of scope) — biggest remaining gap |
| Maintainability | 55 | **70** | Validation + tests + named constants make future changes safer to make |
| Frontend | 45 | 45 | Out of scope this pass (no UX/design changes requested) |
| **Production Readiness (overall)** | **39** | **~67** | See below |

**67, not 90+.** The two Criticals and the High findings that were pure
code fixes are done and verified. What's still missing to cross 90 is
infrastructure that can't be added by editing files in this repo:
horizontal scaling (needs Redis), real monitoring/APM (needs an external
account), a load-tested production database tier, and CI/CD running the
new test suite on every push. These are flagged, not hidden — see the
Production Readiness Checklist in the original audit artifact for the
remaining list.

## Next stage (if continuing toward 90+)

1. Wire `npm test` into a CI pipeline (GitHub Actions) — currently only
   runs when invoked manually.
2. Redis pub/sub for `bus.js` — unblocks horizontal scaling, the single
   largest remaining architectural gap.
3. Sign up for an APM/error-tracking service and wire it to the existing
   `console.error` call sites (they're already structured enough to
   redirect).
4. CHECK constraints on `orders.status`/`products.price`/`products.stock`
   at the DB level, not just application-level validation.
5. A real load test against a staging deployment (not this local
   machine) once the above is in place.
