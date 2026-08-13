const pool = require('./config/database');

// Единственный источник правды по схеме, которую поддерживает рантайм.
// init.sql остаётся сценарием для самого первого разворачивания базы
// (users/products/orders/...), а всё, что появилось после — этот список,
// применяемый последовательно и идемпотентно (IF NOT EXISTS везде) при
// каждом старте сервера. Раньше эти операторы были размазаны по
// automation.js/history.js/notifications.js/earnings.js, каждый со своим
// CREATE TABLE — 'settings', например, создавался в двух местах.
//
// Каждая запись — { name, sql }. name пишется в migrations_log, чтобы было
// видно, что уже применялось (сами операторы всё равно IF NOT EXISTS, так
// что повторный прогон безопасен и без лога — лог только для видимости).
const MIGRATIONS = [
  {
    name: '001_settings_table',
    sql: `CREATE TABLE IF NOT EXISTS settings (
      key VARCHAR(50) PRIMARY KEY,
      value JSONB NOT NULL,
      updated_at TIMESTAMP DEFAULT NOW()
    )`,
  },
  {
    name: '002_orders_delivered_completed_at',
    sql: `ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP;
          ALTER TABLE orders ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;`,
  },
  {
    name: '003_automation_errors_table',
    sql: `CREATE TABLE IF NOT EXISTS automation_errors (
      id SERIAL PRIMARY KEY,
      order_id INT REFERENCES orders(id) ON DELETE CASCADE,
      step VARCHAR(50) NOT NULL,
      error_message TEXT NOT NULL,
      retry_count INT DEFAULT 1,
      resolved BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT NOW()
    )`,
  },
  {
    name: '004_order_history_table',
    sql: `CREATE TABLE IF NOT EXISTS order_history (
      id SERIAL PRIMARY KEY,
      order_id INT REFERENCES orders(id) ON DELETE CASCADE,
      actor VARCHAR(20) NOT NULL,
      actor_user_id INT REFERENCES users(id),
      action VARCHAR(50) NOT NULL,
      details JSONB,
      created_at TIMESTAMP DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_order_history_order_id ON order_history(order_id);`,
  },
  {
    name: '005_notifications_table',
    sql: `CREATE TABLE IF NOT EXISTS notifications (
      id SERIAL PRIMARY KEY,
      user_id INT REFERENCES users(id) ON DELETE CASCADE,
      order_id INT REFERENCES orders(id) ON DELETE CASCADE,
      title VARCHAR(200) NOT NULL,
      message TEXT,
      read BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);`,
  },
  {
    name: '006_earnings_table',
    sql: `CREATE TABLE IF NOT EXISTS earnings (
      id SERIAL PRIMARY KEY,
      user_id INT REFERENCES users(id),
      order_id INT REFERENCES orders(id) ON DELETE CASCADE,
      role VARCHAR(20) NOT NULL,
      amount DECIMAL(10,2) NOT NULL,
      created_at TIMESTAMP DEFAULT NOW(),
      UNIQUE(order_id, role)
    )`,
  },
  {
    // Production audit finding: JOINs/filters on these columns table-scanned
    // with zero indexes (routes/orders.js: GET /my, /picker, /delivery, and
    // automation.js sweep() all filter on one of these every call).
    name: '007_orders_indexes',
    sql: `CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
          CREATE INDEX IF NOT EXISTS idx_orders_picker_id ON orders(picker_user_id);
          CREATE INDEX IF NOT EXISTS idx_orders_delivery_id ON orders(delivery_user_id);
          CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
          CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
          CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);`,
  },
  {
    // Закуп/Purchasing: per-product reorder threshold. Default 5 matches the
    // hardcoded red-highlight value Products.jsx used before this existed.
    name: '008_products_min_stock',
    sql: `ALTER TABLE products ADD COLUMN IF NOT EXISTS min_stock INT NOT NULL DEFAULT 5;`,
  },
  {
    // Profile: saved delivery addresses (map-picked or typed) + liked
    // products. Both are pure customer-side convenience features — no other
    // table references them, so they're safe to add as a single migration.
    name: '009_addresses_favorites',
    sql: `CREATE TABLE IF NOT EXISTS addresses (
      id SERIAL PRIMARY KEY,
      user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      label VARCHAR(50),
      address_text TEXT NOT NULL,
      lat DOUBLE PRECISION,
      lng DOUBLE PRECISION,
      is_default BOOLEAN DEFAULT false,
      created_at TIMESTAMP DEFAULT NOW()
    );
    CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON addresses(user_id);

    CREATE TABLE IF NOT EXISTS favorites (
      id SERIAL PRIMARY KEY,
      user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      created_at TIMESTAMP DEFAULT NOW(),
      UNIQUE(user_id, product_id)
    );
    CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites(user_id);`,
  },
];

async function run() {
  await pool.query(`CREATE TABLE IF NOT EXISTS migrations_log (
    name VARCHAR(100) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT NOW()
  )`);
  const { rows } = await pool.query('SELECT name FROM migrations_log');
  const applied = new Set(rows.map((r) => r.name));

  for (const migration of MIGRATIONS) {
    if (applied.has(migration.name)) continue;
    await pool.query(migration.sql);
    await pool.query('INSERT INTO migrations_log (name) VALUES ($1) ON CONFLICT DO NOTHING', [migration.name]);
    console.log(`  migration ${migration.name} applied`);
  }
}

module.exports = { run };
