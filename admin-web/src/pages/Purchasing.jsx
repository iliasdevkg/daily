import { useState, useEffect } from 'react'
import { api } from '../api.js'
import { PageShell, Spinner } from './Dashboard.jsx'
import Icon from '../components/Icon.jsx'

// Закуп: продукты, чей остаток опустился до порога (min_stock) или ниже —
// сортировка от самого критичного дефицита к наименее срочному, чтобы
// админ сразу видел, что закупать в первую очередь.
export default function Purchasing() {
  const [products, setProducts] = useState([])
  const [loading, setLoading] = useState(true)
  const [restock, setRestock] = useState({}) // { [id]: draftValue }
  const [saving, setSaving] = useState(null)
  const [error, setError] = useState('')

  async function load() {
    setError('')
    try {
      setProducts(await api.getLowStockProducts())
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  async function saveRestock(p) {
    const raw = restock[p.id]
    const newStock = parseInt(raw, 10)
    if (!Number.isInteger(newStock) || newStock < 0) return
    setSaving(p.id)
    try {
      await api.updateProduct(p.id, {
        // p.price/p.min_stock came straight off the API response — DECIMAL
        // columns (price) come back as strings from pg, and the backend's
        // PRODUCT_SCHEMA requires an actual number (isNonNegativeNumber
        // checks typeof === 'number'), so sending it through unconverted
        // 400s. Same defensive parseInt on min_stock in case it's ever null.
        name: p.name, description: p.description, price: parseFloat(p.price),
        stock: newStock, image_url: p.image_url, category_id: p.category_id,
        is_active: p.is_active, min_stock: parseInt(p.min_stock, 10) || 0,
      })
      setRestock(r => { const n = { ...r }; delete n[p.id]; return n })
      await load()
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(null)
    }
  }

  if (loading) return <PageShell title="Закуп"><Spinner /></PageShell>

  return (
    <PageShell title={`Закуп (${products.length})`}>
      <div style={{ marginBottom: 16, fontSize: 13.5, color: 'var(--text-2)' }}>
        Товары, чей остаток на складе достиг порога пополнения или ниже — их нужно закупить в первую очередь.
      </div>

      {error && (
        <div style={{ padding: '10px 14px', background: '#FEE2E2', borderRadius: 10, color: '#991B1B', fontSize: 14, marginBottom: 16 }}>
          {error}
        </div>
      )}

      <div style={{ background: 'white', borderRadius: 20, border: '1.5px solid #F4F4F5', overflow: 'hidden', overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 640 }}>
          <thead>
            <tr style={{ background: '#FAFAF7' }}>
              {['Товар', 'Категория', 'Остаток', 'Порог', 'Дефицит', 'Пополнить'].map(h => (
                <th key={h} style={{ padding: '10px 16px', textAlign: 'left', fontSize: 12, fontWeight: 600, color: '#71717A' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {products.map(p => {
              const deficit = Math.max(0, p.min_stock - p.stock)
              return (
                <tr key={p.id} style={{ borderTop: '1px solid #F4F4F5' }}>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div style={{
                        width: 36, height: 36, borderRadius: 9, background: '#FEE2E2',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        color: '#EF4444', flexShrink: 0,
                      }}><Icon name="alert" size={16} /></div>
                      <div style={{ fontSize: 14, fontWeight: 600 }}>{p.name}</div>
                    </div>
                  </td>
                  <td style={{ padding: '12px 16px', fontSize: 13, color: '#71717A' }}>{p.category_name || '—'}</td>
                  <td style={{ padding: '12px 16px', fontSize: 14, fontWeight: 700, color: '#EF4444' }}>{p.stock} шт</td>
                  <td style={{ padding: '12px 16px', fontSize: 13, color: '#71717A' }}>{p.min_stock} шт</td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{
                      padding: '4px 10px', borderRadius: 99, fontSize: 12, fontWeight: 700,
                      background: '#FEE2E2', color: '#991B1B',
                    }}>−{deficit} шт</span>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <input
                        type="number"
                        placeholder={`${p.stock}`}
                        value={restock[p.id] ?? ''}
                        onChange={e => setRestock(r => ({ ...r, [p.id]: e.target.value }))}
                        style={{
                          width: 76, padding: '7px 10px', border: '1.5px solid #E4E4E7', borderRadius: 8,
                          fontSize: 13, outline: 'none',
                        }}
                      />
                      <button
                        onClick={() => saveRestock(p)}
                        disabled={saving === p.id || restock[p.id] == null || restock[p.id] === ''}
                        style={{
                          padding: '7px 12px', background: '#33D633', color: 'white', border: 'none',
                          borderRadius: 8, fontSize: 12.5, fontWeight: 600, cursor: 'pointer',
                          opacity: saving === p.id ? 0.6 : 1,
                        }}
                      >
                        {saving === p.id ? '...' : 'Сохранить'}
                      </button>
                    </div>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {products.length === 0 && (
          <div style={{ padding: 40, textAlign: 'center', color: '#A1A1AA' }}>
            Все товары в достатке — дефицита нет
          </div>
        )}
      </div>
    </PageShell>
  )
}
