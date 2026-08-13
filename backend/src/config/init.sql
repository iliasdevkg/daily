CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE NOT NULL,
  phone VARCHAR(20),
  password VARCHAR(255) NOT NULL,
  role VARCHAR(20) DEFAULT 'customer', -- customer | admin | delivery | picker
  address TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  image_url TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL,
  stock INT DEFAULT 0,
  image_url TEXT,
  category_id INT REFERENCES categories(id) ON DELETE SET NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  delivery_user_id INT REFERENCES users(id),
  picker_user_id INT REFERENCES users(id),
  status VARCHAR(30) DEFAULT 'pending', -- pending | confirmed | packing | transit | delivered | cancelled
  total DECIMAL(10,2) NOT NULL,
  address TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
  id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  product_id INT REFERENCES products(id),
  quantity INT NOT NULL,
  price DECIMAL(10,2) NOT NULL
);

-- Alter existing orders table to add picker_user_id if not exists
ALTER TABLE orders ADD COLUMN IF NOT EXISTS picker_user_id INT REFERENCES users(id);

-- Timestamps used by the auto-complete rule (orders.js sets delivered_at when
-- status -> 'delivered'; automation.js sets completed_at when it later
-- auto-transitions delivered -> completed).
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMP;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;

-- Audit trail: one row per state change, written by order-history.js from
-- the same 'order' bus events automation.js and orders.js already emit.
CREATE TABLE IF NOT EXISTS order_history (
  id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  actor VARCHAR(20) NOT NULL,        -- system | admin | picker | delivery | customer
  actor_user_id INT REFERENCES users(id),
  action VARCHAR(50) NOT NULL,       -- created | confirmed | picker_assigned | packing | delivery_assigned | transit | delivered | completed | cancelled
  details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_order_history_order_id ON order_history(order_id);

-- Customer-facing notifications, written by notifications.js from the same
-- bus events. Pushed live over SSE (see routes/events.js) and readable
-- on demand via GET /api/notifications/my.
CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id) ON DELETE CASCADE,
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  message TEXT,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);

-- Picker/courier payouts, one row per order per role, written by
-- earnings.js when an order reaches 'delivered'. Rates come from the
-- 'earnings' key in the settings table (see automation.js pattern).
CREATE TABLE IF NOT EXISTS earnings (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id),
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  role VARCHAR(20) NOT NULL,         -- picker | delivery
  amount DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(order_id, role)
);

-- Fail-safe log: automation.js writes here instead of only console.error,
-- so a stuck order is visible and actionable from the admin UI, not just logs.
CREATE TABLE IF NOT EXISTS automation_errors (
  id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  step VARCHAR(50) NOT NULL,
  error_message TEXT NOT NULL,
  retry_count INT DEFAULT 0,
  resolved BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Default users (password for all: "password")
INSERT INTO users (name, email, password, role)
VALUES ('Admin', 'admin@delivery.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (name, email, password, role, phone)
VALUES ('Айбек Доставщик', 'delivery@daily.kg', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'delivery', '+996700111222')
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (name, email, password, role, phone)
VALUES ('Гүлзат Зборщик', 'picker@daily.kg', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'picker', '+996700333444')
ON CONFLICT (email) DO NOTHING;
