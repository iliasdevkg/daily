import { useState, useEffect } from 'react'
import { api } from '../api.js'
import { PageShell, Spinner } from './Dashboard.jsx'
import { Modal } from './Products.jsx'

const ROLES = [
  { value: 'customer',  label: 'Клиент',   color: '#38BDF8' },
  { value: 'picker',    label: 'Сборщик',  color: '#A78BFA' },
  { value: 'delivery',  label: 'Курьер',   color: '#FBBF24' },
  { value: 'admin',     label: 'Админ',    color: '#33D633' },
]

const STATUS_LABEL = {
  pending: 'В ожидании', confirmed: 'Подтверждён', packing: 'Собирается',
  transit: 'В пути', delivered: 'Доставлен', completed: 'Завершён', cancelled: 'Отменён',
}

export default function Users() {
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('all')
  const [changing, setChanging] = useState(null)
  const [history, setHistory] = useState(null) // { user, orders, loading } | null

  async function load() {
    try { setUsers(await api.getUsers()) }
    finally { setLoading(false) }
  }

  async function openHistory(u) {
    setHistory({ user: u, orders: [], loading: true })
    try {
      const orders = await api.getUserOrders(u.id)
      setHistory({ user: u, orders, loading: false })
    } catch (err) {
      setHistory({ user: u, orders: [], loading: false, error: err.message })
    }
  }

  useEffect(() => { load() }, [])

  async function changeRole(id, role) {
    setChanging(id)
    try {
      await api.updateUserRole(id, role)
      await load()
    } finally {
      setChanging(null)
    }
  }

  const filtered = users.filter(u => {
    const matchSearch = u.name.toLowerCase().includes(search.toLowerCase()) ||
      u.email.toLowerCase().includes(search.toLowerCase())
    const matchRole = roleFilter === 'all' || u.role === roleFilter
    return matchSearch && matchRole
  })

  if (loading) return <PageShell title="Пользователи"><Spinner /></PageShell>

  return (
    <PageShell
      title={`Пользователи (${users.length})`}
      actions={
        <div style={{ display: 'flex', gap: 10 }}>
          <input
            placeholder="Поиск..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            style={{ padding: '9px 14px', border: '1.5px solid #E4E4E7', borderRadius: 10, fontSize: 14, outline: 'none', background: 'white', width: 220 }}
          />
          <select
            value={roleFilter}
            onChange={e => setRoleFilter(e.target.value)}
            style={{ padding: '9px 14px', border: '1.5px solid #E4E4E7', borderRadius: 10, fontSize: 14, outline: 'none', background: 'white', cursor: 'pointer' }}
          >
            <option value="all">Все</option>
            {ROLES.map(r => <option key={r.value} value={r.value}>{r.label}</option>)}
          </select>
        </div>
      }
    >
      {/* Role stats */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 20 }}>
        {ROLES.map(r => {
          const cnt = users.filter(u => u.role === r.value).length
          return (
            <div key={r.value} style={{ padding: '12px 20px', background: 'white', borderRadius: 14, border: '1.5px solid #F4F4F5', display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 10, height: 10, borderRadius: '50%', background: r.color }} />
              <span style={{ fontSize: 14, fontWeight: 600, color: '#0F0F0D' }}>{r.label}</span>
              <span style={{ fontSize: 20, fontWeight: 800, color: r.color }}>{cnt}</span>
            </div>
          )
        })}
      </div>

      {/* CHANGED: overflowX:auto lets the table scroll horizontally on mobile instead of breaking the layout */}
      <div style={{ background: 'white', borderRadius: 20, border: '1.5px solid #F4F4F5', overflow: 'hidden', overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 560 }}>
          <thead>
            <tr style={{ background: '#FAFAF7' }}>
              {['Пользователь', 'Email', 'Телефон', 'Адрес', 'Текущая роль', 'Изменить роль', 'Дата', ''].map(h => (
                <th key={h} style={{ padding: '10px 16px', textAlign: 'left', fontSize: 12, fontWeight: 600, color: '#71717A' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map(u => {
              const roleInfo = ROLES.find(r => r.value === u.role) || { label: u.role, color: '#A1A1AA' }
              return (
                <tr key={u.id} style={{ borderTop: '1px solid #F4F4F5' }}>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      <div style={{
                        width: 36, height: 36, borderRadius: '50%', flexShrink: 0,
                        background: roleInfo.color + '33',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontSize: 16, fontWeight: 700, color: roleInfo.color,
                      }}>
                        {u.name?.[0]?.toUpperCase() || '?'}
                      </div>
                      <div style={{ fontSize: 14, fontWeight: 600 }}>{u.name}</div>
                    </div>
                  </td>
                  <td style={{ padding: '12px 16px', fontSize: 13, color: '#52525B' }}>{u.email}</td>
                  <td style={{ padding: '12px 16px', fontSize: 13, color: '#71717A' }}>{u.phone || '—'}</td>
                  <td style={{ padding: '12px 16px', fontSize: 12, color: '#A1A1AA', maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {u.address || '—'}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <span style={{ padding: '4px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600, background: roleInfo.color + '22', color: roleInfo.color }}>
                      {roleInfo.label}
                    </span>
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    <div style={{ display: 'flex', gap: 6 }}>
                      {ROLES.filter(r => r.value !== u.role).map(r => (
                        <button
                          key={r.value}
                          onClick={() => changeRole(u.id, r.value)}
                          disabled={changing === u.id}
                          style={{
                            padding: '5px 10px', borderRadius: 8, border: `1.5px solid ${r.color}`,
                            background: 'white', color: r.color, fontSize: 12, fontWeight: 600,
                            cursor: 'pointer', opacity: changing === u.id ? 0.5 : 1,
                          }}
                        >
                          {r.label}
                        </button>
                      ))}
                    </div>
                  </td>
                  <td style={{ padding: '12px 16px', fontSize: 12, color: '#A1A1AA' }}>
                    {new Date(u.created_at).toLocaleDateString('ru')}
                  </td>
                  <td style={{ padding: '12px 16px' }}>
                    {(u.role === 'picker' || u.role === 'delivery') && (
                      <button
                        onClick={() => openHistory(u)}
                        style={{
                          padding: '6px 12px', borderRadius: 8, border: '1.5px solid #E4E4E7',
                          background: 'white', color: '#0F0F0D', fontSize: 12, fontWeight: 600, cursor: 'pointer',
                        }}
                      >
                        История
                      </button>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <div style={{ padding: 40, textAlign: 'center', color: '#A1A1AA' }}>Нет пользователей</div>
        )}
      </div>

      {history && (
        <Modal title={`История заказов — ${history.user.name}`} onClose={() => setHistory(null)}>
          {history.loading && <div style={{ padding: 20, textAlign: 'center', color: '#A1A1AA' }}>Загрузка...</div>}
          {history.error && (
            <div style={{ padding: '10px 14px', background: '#FEE2E2', borderRadius: 10, color: '#991B1B', fontSize: 14 }}>
              {history.error}
            </div>
          )}
          {!history.loading && !history.error && history.orders.length === 0 && (
            <div style={{ padding: 20, textAlign: 'center', color: '#A1A1AA' }}>Заказов пока нет</div>
          )}
          {!history.loading && history.orders.length > 0 && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, maxHeight: 420, overflowY: 'auto' }}>
              {history.orders.map(o => (
                <div key={o.id} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12,
                  padding: '10px 14px', background: '#FAFAF7', borderRadius: 12,
                }}>
                  <div>
                    <div style={{ fontSize: 13.5, fontWeight: 600 }}>#{o.id} · {o.customer_name || 'Клиент'}</div>
                    <div style={{ fontSize: 12, color: '#A1A1AA' }}>{o.address} · {new Date(o.created_at).toLocaleDateString('ru')}</div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: 13, fontWeight: 700 }}>{parseFloat(o.total).toLocaleString()} с</div>
                    <span style={{ fontSize: 11, fontWeight: 600, color: '#52525B' }}>{STATUS_LABEL[o.status] || o.status}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </Modal>
      )}
    </PageShell>
  )
}
