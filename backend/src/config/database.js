const { Pool } = require('pg');
require('dotenv').config();

// Render/Supabase deploys provide a single DATABASE_URL (Postgres requires
// SSL on Supabase's pooler). Local dev keeps using the discrete DB_* vars
// with no SSL, since a local Postgres has no certificate to verify.
const POOL_OPTIONS = {
  max: 20,                     // ceiling on concurrent DB connections this process opens
  idleTimeoutMillis: 30000,    // release an idle client back to the OS after 30s
  connectionTimeoutMillis: 5000, // fail fast (not hang forever) if the pool is exhausted
};

const pool = process.env.DATABASE_URL
  ? new Pool({
      ...POOL_OPTIONS,
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false },
    })
  : new Pool({
      ...POOL_OPTIONS,
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
    });

// Acquire-then-release, not the pool.connect(callback) form — that form
// hands back a checked-out client with no way to release it, which leaves
// one connection permanently open and makes pool.end() (seed.js, graceful
// shutdown in app.js) hang forever waiting for it to return.
pool
  .connect()
  .then((client) => {
    console.log('Connected to PostgreSQL');
    client.release();
  })
  .catch((err) => console.error('Database connection error:', err.message));

// Required by the pg docs: an idle client that errors (network blip, DB
// restart) emits 'error' on the pool. Without a listener here, Node treats
// it as an uncaught exception and kills the whole process — one transient
// network hiccup would otherwise take down the entire API.
pool.on('error', (err) => {
  console.error('Unexpected error on idle PostgreSQL client:', err.message);
});

module.exports = pool;
