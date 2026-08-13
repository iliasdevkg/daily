import { useState, useEffect } from 'react'
import { api } from '../api.js'
import { PageShell, Spinner } from './Dashboard.jsx'
import { Modal } from './Products.jsx'
import Icon from '../components/Icon.jsx'

const EMPTY = { name: '', image_url: '' }

export default function Categories() {
  const [cats, setCats] = useState([])
  const [loading, setLoading] = useState(true)
  const [modal, setModal] = useState(null)
  const [form, setForm] = useState(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  async function load() {
    try {
      setCats(await api.getCategories())
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  function openCreate() { setForm(EMPTY); setError(''); setModal('create') }
  function openEdit(c) { setForm({ name: c.name, image_url: c.image_url || '' }); setError(''); setModal(c) }

  async function handleSave() {
    setError(''); setSaving(true)
    try {
      if (modal === 'create') await api.createCategory(form)
      else await api.updateCategory(modal.id, form)
      await load()
      setModal(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(id) {
    if (!confirm('Удалить категорию?')) return
    await api.deleteCategory(id)
    await load()
  }

  if (loading) return <PageShell title="Категории"><Spinner /></PageShell>

  return (
    <PageShell
      title={`Категории (${cats.length})`}
      actions={
        <button onClick={openCreate} style={btn('#0F0F0D')}>+ Новая категория</button>
      }
    >
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 16 }}>
        {cats.map(c => (
          <div key={c.id} style={{
            background: 'white', borderRadius: 20, border: '1.5px solid #F4F4F5',
            overflow: 'hidden',
          }}>
            <div style={{
              height: 120, background: '#F4F4F5', display: 'flex',
              alignItems: 'center', justifyContent: 'center', fontSize: 48,
              overflow: 'hidden',
            }}>
              {c.image_url
                ? (c.image_url.startsWith('http')
                    ? <img src={c.image_url} alt={c.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : c.image_url)
                : <span style={{ color: '#A1A1AA', display: 'flex' }}><Icon name="folder" size={40} /></span>}
            </div>
            <div style={{ padding: 16 }}>
              <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 12 }}>{c.name}</div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button onClick={() => openEdit(c)} style={{ ...btn('#F4F4F5', '#0F0F0D'), display: 'inline-flex', alignItems: 'center', gap: 6 }}><Icon name="pencil" size={13} /> Изменить</button>
                <button onClick={() => handleDelete(c.id)} style={{ ...btn('#FEE2E2', '#EF4444'), display: 'inline-flex', alignItems: 'center' }}><Icon name="trash" size={14} /></button>
              </div>
            </div>
          </div>
        ))}
        {cats.length === 0 && (
          <div style={{ gridColumn: '1/-1', textAlign: 'center', padding: 60, color: '#A1A1AA', background: 'white', borderRadius: 20 }}>
            Нет категорий
          </div>
        )}
      </div>

      {modal && (
        <Modal title={modal === 'create' ? 'Новая категория' : 'Изменить категорию'} onClose={() => setModal(null)}>
          <Field label="Название *">
            <Inp value={form.name} onChange={v => setForm(f => ({ ...f, name: v }))} placeholder="Название категории" />
          </Field>
          <Field label="URL изображения">
            <Inp value={form.image_url} onChange={v => setForm(f => ({ ...f, image_url: v }))} placeholder="https://..." />
          </Field>
          {error && <div style={{ padding: '10px 14px', background: '#FEE2E2', borderRadius: 10, color: '#991B1B', fontSize: 14 }}>{error}</div>}
          <button onClick={handleSave} disabled={saving} style={btn('#33D633')}>
            {saving ? 'Сохранение...' : 'Сохранить'}
          </button>
        </Modal>
      )}
    </PageShell>
  )
}

function btn(bg, color = 'white') {
  return { padding: '9px 16px', background: bg, color, border: 'none', borderRadius: 10, fontSize: 13, fontWeight: 600, cursor: 'pointer' }
}
const iStyle = { width: '100%', padding: '10px 12px', border: '1.5px solid #E4E4E7', borderRadius: 10, fontSize: 14, outline: 'none', fontFamily: 'Inter, sans-serif', background: '#FAFAF7' }
function Inp({ value, onChange, placeholder }) {
  return <input value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} style={iStyle} onFocus={e => e.target.style.borderColor = '#33D633'} onBlur={e => e.target.style.borderColor = '#E4E4E7'} />
}
function Field({ label, children }) {
  return <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}><label style={{ fontSize: 13, fontWeight: 600, color: '#52525B' }}>{label}</label>{children}</div>
}
