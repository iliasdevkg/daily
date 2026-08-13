// Minimal catalog seed — init.sql only creates the 3 role accounts
// (admin/picker/delivery), a fresh production database otherwise has zero
// categories/products, meaning no order can ever be placed. Idempotent
// (ON CONFLICT DO NOTHING keyed on name) — safe to run more than once.
//
// Usage: node scripts/seed.js  (run from backend/, needs the same DB env
// vars as the app itself — DATABASE_URL or DB_*).
require('dotenv').config();
const pool = require('../src/config/database');

const CATEGORIES = [
  { name: 'Хлеб и выпечка', image_url: '🍞' },
  { name: 'Молочные продукты', image_url: '🥛' },
  { name: 'Напитки', image_url: '🥤' },
  { name: 'Овощи и фрукты', image_url: '🍎' },
  { name: 'Мясо', image_url: '🍗' },
];

const PRODUCTS = [
  { category: 'Хлеб и выпечка', name: 'Белый хлеб', description: 'Свежий хлеб, 400г', price: 45, stock: 50, image_url: '🍞' },
  { category: 'Молочные продукты', name: 'Молоко 1л', description: 'Пастеризованное, 3.2%', price: 80, stock: 40, image_url: '🥛' },
  { category: 'Молочные продукты', name: 'Йогурт натуральный', description: '200г', price: 60, stock: 30, image_url: '🍦' },
  { category: 'Напитки', name: 'Чёрный чай', description: '100г', price: 80, stock: 76, image_url: '🍵' },
  { category: 'Напитки', name: 'Вода питьевая 1.5л', description: 'Негазированная', price: 35, stock: 100, image_url: '💧' },
  { category: 'Овощи и фрукты', name: 'Яблоки', description: '1кг', price: 90, stock: 60, image_url: '🍎' },
  { category: 'Овощи и фрукты', name: 'Бананы', description: '1кг', price: 110, stock: 45, image_url: '🍌' },
  { category: 'Мясо', name: 'Куриное филе', description: '1кг, охлаждённое', price: 320, stock: 20, image_url: '🍗' },
];

async function seed() {
  const categoryIds = {};
  for (const cat of CATEGORIES) {
    const { rows } = await pool.query(
      `INSERT INTO categories (name, image_url) VALUES ($1, $2)
       ON CONFLICT DO NOTHING RETURNING id`,
      [cat.name, cat.image_url]
    );
    const existing = rows[0] || (await pool.query('SELECT id FROM categories WHERE name = $1', [cat.name])).rows[0];
    categoryIds[cat.name] = existing.id;
  }
  console.log(`Категориялар: ${Object.keys(categoryIds).length}`);

  let productsAdded = 0;
  for (const p of PRODUCTS) {
    const exists = await pool.query('SELECT id FROM products WHERE name = $1', [p.name]);
    if (exists.rows[0]) continue;
    await pool.query(
      `INSERT INTO products (name, description, price, stock, image_url, category_id) VALUES ($1,$2,$3,$4,$5,$6)`,
      [p.name, p.description, p.price, p.stock, p.image_url, categoryIds[p.category]]
    );
    productsAdded++;
  }
  console.log(`Товарлар кошулду: ${productsAdded} (жалпы ${PRODUCTS.length})`);

  await pool.end();
}

seed().catch((err) => {
  console.error('Seed error:', err.message);
  process.exit(1);
});
