import { useState, useEffect } from 'react'
import { api } from '../api.js'
import { PageShell, Spinner } from './Dashboard.jsx'
import Icon from '../components/Icon.jsx'

const EMPTY = { name: '', description: '', price: '', stock: '', image_url: '', category_id: '', min_stock: 5 }

export default function Products() {
  const [products, setProducts] = useState([])
  const [categories, setCategories] = useState([])
  const [loading, setLoading] = useState(true)
  const [modal, setModal] = useState(null) // null | 'create' | product_obj
  const [form, setForm] = useState(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [search, setSearch] = useState('')

  async function load() {
    try {
      const [p, c] = await Promise.all([api.getProducts(), api.getCategories()])
      setProducts(p)
      setCategories(c)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  function openCreate() {
    setForm(EMPTY)
    setError('')
    setModal('create')
  }

  function openEdit(p) {
    setForm({
      name: p.name, description: p.description || '',
      price: p.price, stock: p.stock, image_url: p.image_url || '',
      category_id: p.category_id || '', min_stock: p.min_stock ?? 5,
    })
    setError('')
    setModal(p)
  }

  async function handleSave() {
    setError('')
    setSaving(true)
    try {
      const data = {
        ...form,
        price: parseFloat(form.price),
        stock: parseInt(form.stock),
        category_id: form.category_id || null,
        min_stock: parseInt(form.min_stock) || 0,
      }
      if (modal === 'create') {
        await api.createProduct(data)
      } else {
        await api.updateProduct(modal.id, { ...data, is_active: modal.is_active })
      }
      await load()
      setModal(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(id) {
    if (!confirm('Удалить товар?')) return
    await api.deleteProduct(id)
    await load()
  }

  const filtered = products.filter(p =>
    p.name.toLowerCase().includes(search.toLowerCase())
  )

  if (loading) return <PageShell title="Товары"><Spinner /></PageShell>

  return (
    <PageShell
      title={`Товары (${products.length})`}
      actions={
        <div style={{ display: 'flex', gap: 10 }}>
          <input
            placeholder="Поиск..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{
              padding: '9px 14px', border: '1.5px solid #E4E4E7', borderRadius: 10,
              fontSize: 14, outline: 'none', background: 'white', width: 200,
            }}
          />
          <button onClick={openCreate} style={btnStyle('#0F0F0D')}>
            + Новый товар
          </button>
        </div>
      }
    >
      {/* CHANGED: overflowX:auto lets the table scroll horizontally on mobile instead of breaking the layout */}
      <div style={{ background: 'white', borderRadius: 20, border: '1.5px solid #F4F4F5', overflow: 'hidden', overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 640 }}>
          <thead>
            <tr style={{ background: '#FAFAF7' }}>
              {['Товар', 'Категория', 'Цена', 'Остаток', 'Статус', ''].map(h => (
                <th key={h} style={{ padding: '10px 16px', textAlign: 'left', fontSize: 12, fontWeight: 600, color: '#71717A' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map(p => (
              <tr key={p.id} style={{ borderTop: '1px solid #F4F4F5' }}>
                <td style={{ padding: '12px 16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: 10, background: '#F4F4F5',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontSize: 20, overflow: 'hidden', flexShrink: 0,
                    }}>
                      {p.image_url
                        ? (p.image_url.startsWith('http')
                            ? <img src={p.image_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                            : p.image_url)
                        : <span style={{ color: '#A1A1AA', display: 'flex' }}><Icon name="bag" size={18} /></span>}
                    </div>
                    <div>
                      <div style={{ fontSize: 14, fontWeight: 600 }}>{p.name}</div>
                      <div style={{ fontSize: 12, color: '#A1A1AA', maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {p.description || '—'}
                      </div>
                    </div>
                  </div>
                </td>
                <td style={{ padding: '12px 16px', fontSize: 13, color: '#71717A' }}>{p.category_name || '—'}</td>
                <td style={{ padding: '12px 16px', fontSize: 14, fontWeight: 700 }}>{parseFloat(p.price).toLocaleString()} с</td>
                <td style={{ padding: '12px 16px', fontSize: 13 }}>
                  <span style={{ color: p.stock <= (p.min_stock ?? 5) ? '#EF4444' : '#0F0F0D', fontWeight: p.stock <= (p.min_stock ?? 5) ? 700 : 400 }}>
                    {p.stock} шт
                  </span>
                </td>
                <td style={{ padding: '12px 16px' }}>
                  <span style={{
                    padding: '4px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600,
                    background: p.is_active ? '#DCFCE7' : '#F4F4F5',
                    color: p.is_active ? '#15803D' : '#71717A',
                  }}>{p.is_active ? 'Активен' : 'Скрыт'}</span>
                </td>
                <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                  <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                    <button onClick={() => openEdit(p)} style={{ ...btnSmall('#F4F4F5', '#0F0F0D'), display: 'inline-flex', alignItems: 'center' }}><Icon name="pencil" size={14} /></button>
                    <button onClick={() => handleDelete(p.id)} style={{ ...btnSmall('#FEE2E2', '#EF4444'), display: 'inline-flex', alignItems: 'center' }}><Icon name="trash" size={14} /></button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <div style={{ padding: 40, textAlign: 'center', color: '#A1A1AA' }}>Нет товаров</div>
        )}
      </div>

      {/* Modal */}
      {modal && (
        <Modal title={modal === 'create' ? 'Новый товар' : 'Изменить товар'} onClose={() => setModal(null)}>
          <FormField label="Название *">
            <Input value={form.name} onChange={v => setForm(f => ({ ...f, name: v }))} placeholder="Название товара" />
          </FormField>
          <FormField label="Описание">
            <textarea
              value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
              placeholder="Краткое описание"
              rows={3}
              style={{ ...inputStyle, resize: 'vertical' }}
            />
          </FormField>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <FormField label="Цена (сом) *">
              <Input type="number" value={form.price} onChange={v => setForm(f => ({ ...f, price: v }))} placeholder="0" />
            </FormField>
            <FormField label="Остаток (шт) *">
              <Input type="number" value={form.stock} onChange={v => setForm(f => ({ ...f, stock: v }))} placeholder="0" />
            </FormField>
          </div>
          <FormField label="Порог пополнения (Закуп), шт">
            <Input type="number" value={form.min_stock} onChange={v => setForm(f => ({ ...f, min_stock: v }))} placeholder="5" />
          </FormField>
          <FormField label="URL изображения">
            <Input value={form.image_url} onChange={v => setForm(f => ({ ...f, image_url: v }))} placeholder="https://..." />
          </FormField>
          <FormField label="Категория">
            <select
              value={form.category_id}
              onChange={e => setForm(f => ({ ...f, category_id: e.target.value }))}
              style={{ ...inputStyle }}
            >
              <option value="">— Выберите —</option>
              {categories.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
          </FormField>
          {error && <ErrBox>{error}</ErrBox>}
          <button onClick={handleSave} disabled={saving} style={btnStyle('#33D633')}>
            {saving ? 'Сохранение...' : 'Сохранить'}
          </button>
        </Modal>
      )}
    </PageShell>
  )
}

// ── Helpers ──────────────────────────────────────────────
function btnStyle(bg) {
  return {
    padding: '10px 18px', background: bg, color: 'white', border: 'none',
    borderRadius: 10, fontSize: 14, fontWeight: 600, cursor: 'pointer',
  }
}
function btnSmall(bg, color) {
  return {
    padding: '6px 10px', background: bg, color, border: 'none',
    borderRadius: 8, fontSize: 13, cursor: 'pointer',
  }
}
const inputStyle = {
  width: '100%', padding: '10px 12px', border: '1.5px solid #E4E4E7',
  borderRadius: 10, fontSize: 14, outline: 'none', fontFamily: 'Inter, sans-serif',
  background: '#FAFAF7',
}
function Input({ value, onChange, ...rest }) {
  return (
    <input
      value={value}
      onChange={e => onChange(e.target.value)}
      style={inputStyle}
      onFocus={e => e.target.style.borderColor = '#33D633'}
      onBlur={e => e.target.style.borderColor = '#E4E4E7'}
      {...rest}
    />
  )
}
function FormField({ label, children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <label style={{ fontSize: 13, fontWeight: 600, color: '#52525B' }}>{label}</label>
      {children}
    </div>
  )
}
function ErrBox({ children }) {
  return (
    <div style={{ padding: '10px 14px', background: '#FEE2E2', borderRadius: 10, color: '#991B1B', fontSize: 14 }}>
      {children}
    </div>
  )
}
export function Modal({ title, onClose, children }) {
  return (
    <>
      <div onClick={onClose} style={{
        position: 'fixed', inset: 0, background: 'rgba(0,0,0,.45)',
        zIndex: 50, backdropFilter: 'blur(4px)',
      }} />
      {/* CHANGED: position/size now live in .admin-modal (index.css) so the
          mobile media query can make this fullscreen instead of a centered box */}
      <div className="admin-modal" style={{
        overflow: 'auto',
        background: 'white', padding: 28, zIndex: 51,
        display: 'flex', flexDirection: 'column', gap: 16,
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
          <div style={{ fontSize: 18, fontWeight: 800 }}>{title}</div>
          <button onClick={onClose} style={{ border: 'none', background: '#F4F4F5', borderRadius: '50%', width: 32, height: 32, fontSize: 16, cursor: 'pointer' }}>×</button>
        </div>
        {children}
      </div>
    </>
  )
}
