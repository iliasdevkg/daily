import { useState, useEffect } from 'react'
import { api, subscribeToOrderEvents } from '../api.js'
import { PageShell, Spinner } from './Dashboard.jsx'
import { Modal } from './Products.jsx'
import Icon from '../components/Icon.jsx'

const STATUSES = [
  { value: 'pending',    label: 'В ожидании',  color: '#FBBF24' },
  { value: 'confirmed',  label: 'Подтверждён', color: '#38BDF8' },
  { value: 'packing',    label: 'Собирается',  color: '#C084FC' },
  { value: 'transit',    label: 'В пути',      color: '#FB923C' },
  { value: 'delivered',  label: 'Доставлен',   color: '#33D633' },
  { value: 'completed',  label: 'Завершён',    color: '#15803D' },
  { value: 'cancelled',  label: 'Отменён',     color: '#EF4444' },
]

const ACTION_LABEL = {
  created: 'Заказ создан',
  'status:confirmed': 'Подтверждён',
  picker_assigned: 'Назначен сборщик',
  'status:packing': 'Сборка начата',
  delivery_assigned: 'Назначен курьер',
  'status:transit': 'Курьер в пути',
  'status:delivered': 'Доставлен',
  'status:completed': 'Завершён',
  'status:cancelled': 'Отменён',
}
const ACTOR_LABEL = {
  system: 'система', admin: 'админ', picker: 'сборщик', delivery: 'курьер', customer: 'клиент',
}

function badge(status) {
  const s = STATUSES.find(x => x.value === status) || { label: status, color: '#A1A1AA' }
  return (
    <span style={{
      padding: '4px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600,
      background: s.color + '22', color: s.color,
    }}>{s.label}</span>
  )
}

export default function Orders() {
  const [orders, setOrders] = useState([])
  const [users, setUsers] = useState([])
  const [loading, setLoading] = useState(true)
  const [filter, setFilter] = useState('all')
  const [selected, setSelected] = useState(null)
  const [newStatus, setNewStatus] = useState('')
  const [pickerAssign, setPickerAssign] = useState('')
  const [deliveryAssign, setDeliveryAssign] = useState('')
  const [saving, setSaving] = useState(false)
  const [confirming, setConfirming] = useState(null)
  const [history, setHistory] = useState([])

  async function load() {
    try {
      const [ords, usrs] = await Promise.all([api.getOrders(), api.getUsers()])
      setOrders(ords)
      setUsers(usrs)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
    const unsubscribe = subscribeToOrderEvents(load)
    return unsubscribe
  }, [])

  function openOrder(o) {
    setSelected(o)
    setNewStatus(o.status)
    setPickerAssign(o.picker_user_id ? String(o.picker_user_id) : '')
    setDeliveryAssign(o.delivery_user_id ? String(o.delivery_user_id) : '')
    setHistory([])
    api.getOrderHistory(o.id).then(setHistory).catch(() => {})
  }

  async function quickConfirm(order) {
    setConfirming(order.id)
    try {
      await api.updateOrderStatus(order.id, 'confirmed')
      await load()
    } finally {
      setConfirming(null)
    }
  }

  async function handleSave() {
    setSaving(true)
    try {
      const extra = {}
      if (pickerAssign) extra.picker_user_id = parseInt(pickerAssign)
      if (deliveryAssign) extra.delivery_user_id = parseInt(deliveryAssign)
      await api.updateOrderStatus(selected.id, newStatus, extra)
      await load()
      setSelected(null)
    } finally {
      setSaving(false)
    }
  }

  const filtered = filter === 'all' ? orders : orders.filter(o => o.status === filter)
  const pickers = users.filter(u => u.role === 'picker')
  const drivers = users.filter(u => u.role === 'delivery')

  if (loading) return <PageShell title="Заказы"><Spinner /></PageShell>

  return (
    <PageShell title={`Заказы (${orders.length})`}>
      {/* Quick stats */}
      {orders.filter(o => o.status === 'pending').length > 0 && (
        <div style={{ background: '#FBBF2418', border: '1.5px solid #FBBF2440', borderRadius: 16, padding: '12px 16px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ color: '#D97706', display: 'flex' }}><Icon name="alert" size={20} /></span>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: '#D97706' }}>
              {orders.filter(o => o.status === 'pending').length} заказов ожидают подтверждения
            </div>
            <div style={{ fontSize: 12, color: '#92400E' }}>Нажмите кнопку "Подтвердить" ниже</div>
          </div>
        </div>
      )}

      {/* Status filter tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20, flexWrap: 'wrap' }}>
        <Tab label={`Все (${orders.length})`} active={filter === 'all'} onClick={() => setFilter('all')} />
        {STATUSES.map(s => {
          const cnt = orders.filter(o => o.status === s.value).length
          return cnt > 0 && (
            <Tab key={s.value} label={`${s.label} (${cnt})`} active={filter === s.value} onClick={() => setFilter(s.value)} color={s.color} />
          )
        })}
      </div>

      {/* CHANGED: overflowX:auto lets the table scroll horizontally on mobile instead of breaking the layout */}
      <div style={{ background: 'white', borderRadius: 20, border: '1.5px solid #F4F4F5', overflow: 'hidden', overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 720 }}>
          <thead>
            <tr style={{ background: '#FAFAF7' }}>
              {['ID', 'Клиент', 'Телефон', 'Адрес', 'Сумма', 'Статус', 'Дата', ''].map(h => (
                <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontSize: 12, fontWeight: 600, color: '#71717A' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map(o => (
              <tr key={o.id} style={{ borderTop: '1px solid #F4F4F5' }}>
                <td style={{ padding: '12px 14px', fontSize: 13, fontWeight: 700 }}>#{o.id}</td>
                <td style={{ padding: '12px 14px', fontSize: 13 }}>{o.customer_name || '—'}</td>
                <td style={{ padding: '12px 14px', fontSize: 13, color: '#71717A' }}>{o.customer_phone || '—'}</td>
                <td style={{ padding: '12px 14px', fontSize: 12, color: '#71717A', maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{o.address}</td>
                <td style={{ padding: '12px 14px', fontSize: 13, fontWeight: 700 }}>{parseFloat(o.total).toLocaleString()} с</td>
                <td style={{ padding: '12px 14px' }}>{badge(o.status)}</td>
                <td style={{ padding: '12px 14px', fontSize: 12, color: '#A1A1AA' }}>{new Date(o.created_at).toLocaleDateString('ru')}</td>
                <td style={{ padding: '12px 14px' }}>
                  <div style={{ display: 'flex', gap: 6 }}>
                    {o.status === 'pending' && (
                      <button
                        onClick={() => quickConfirm(o)}
                        disabled={confirming === o.id}
                        style={{
                          padding: '6px 12px', background: '#38BDF8', color: 'white',
                          border: 'none', borderRadius: 8, fontSize: 12, fontWeight: 700,
                          cursor: 'pointer', opacity: confirming === o.id ? 0.6 : 1,
                        }}
                      >
                        {confirming === o.id ? '...' : <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}><Icon name="check" size={12} strokeWidth={3} />Подтвердить</span>}
                      </button>
                    )}
                    <button onClick={() => openOrder(o)} style={{
                      padding: '6px 12px', background: '#F4F4F5', border: 'none',
                      borderRadius: 8, fontSize: 12, fontWeight: 600, cursor: 'pointer',
                    }}>Открыть</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <div style={{ padding: 40, textAlign: 'center', color: '#A1A1AA' }}>Нет заказов</div>
        )}
      </div>

      {selected && (
        <Modal title={`Заказ #${selected.id}`} onClose={() => setSelected(null)}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Info label="Клиент" value={selected.customer_name || '—'} />
            <Info label="Телефон" value={selected.customer_phone || '—'} />
            <Info label="Сумма" value={`${parseFloat(selected.total).toLocaleString()} сом`} />
            <Info label="Дата" value={new Date(selected.created_at).toLocaleString('ru')} />
          </div>
          <Info label="Адрес" value={selected.address} />
          {selected.note && <Info label="Примечание" value={selected.note} />}

          {/* Items */}
          {selected.items?.[0]?.name && (
            <div>
              <div style={{ fontSize: 13, fontWeight: 600, color: '#52525B', marginBottom: 8 }}>Товары</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {selected.items.filter(i => i.name).map((item, i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 12px', background: '#FAFAF7', borderRadius: 10, fontSize: 14 }}>
                    <span>{item.name} × {item.quantity}</span>
                    <span style={{ fontWeight: 700 }}>{(item.price * item.quantity).toLocaleString()} с</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* История заказа — журнал каждого шага, автоматического и ручного */}
          {history.length > 0 && (
            <div style={{ borderTop: '1px solid #F4F4F5', paddingTop: 16 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: '#52525B', marginBottom: 10 }}>История заказа</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                {history.map(h => (
                  <div key={h.id} style={{ display: 'flex', gap: 10, alignItems: 'baseline', fontSize: 13 }}>
                    <span style={{ color: '#A1A1AA', fontSize: 11, minWidth: 70 }}>
                      {new Date(h.created_at).toLocaleTimeString('ru', { hour: '2-digit', minute: '2-digit' })}
                    </span>
                    <span style={{ flex: 1 }}>{ACTION_LABEL[h.action] || h.action}</span>
                    <span style={{ fontSize: 11, color: '#A1A1AA' }}>{ACTOR_LABEL[h.actor] || h.actor}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Worker assignment */}
          <div style={{ borderTop: '1px solid #F4F4F5', paddingTop: 16 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: '#52525B', marginBottom: 12 }}>Назначить сотрудников</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
              <div>
                <div style={{ fontSize: 12, color: '#A1A1AA', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 5 }}><Icon name="package" size={13} /> Сборщик</div>
                <select
                  value={pickerAssign}
                  onChange={e => setPickerAssign(e.target.value)}
                  style={{ width: '100%', padding: '9px 12px', border: '1.5px solid #E4E4E7', borderRadius: 10, fontSize: 13, outline: 'none', background: 'white', cursor: 'pointer' }}
                >
                  <option value="">— Не назначен —</option>
                  {pickers.map(u => (
                    <option key={u.id} value={u.id}>{u.name}</option>
                  ))}
                </select>
                {selected.picker_name && (
                  <div style={{ fontSize: 11, color: '#71717A', marginTop: 4 }}>Сейчас: {selected.picker_name}</div>
                )}
              </div>
              <div>
                <div style={{ fontSize: 12, color: '#A1A1AA', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 5 }}><Icon name="bike" size={13} /> Доставщик</div>
                <select
                  value={deliveryAssign}
                  onChange={e => setDeliveryAssign(e.target.value)}
                  style={{ width: '100%', padding: '9px 12px', border: '1.5px solid #E4E4E7', borderRadius: 10, fontSize: 13, outline: 'none', background: 'white', cursor: 'pointer' }}
                >
                  <option value="">— Не назначен —</option>
                  {drivers.map(u => (
                    <option key={u.id} value={u.id}>{u.name}</option>
                  ))}
                </select>
                {selected.delivery_name && (
                  <div style={{ fontSize: 11, color: '#71717A', marginTop: 4 }}>Сейчас: {selected.delivery_name}</div>
                )}
              </div>
            </div>
          </div>

          {/* Status change */}
          <div style={{ borderTop: '1px solid #F4F4F5', paddingTop: 16 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: '#52525B', marginBottom: 10 }}>Изменить статус</div>
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
              {STATUSES.map(s => (
                <button key={s.value} onClick={() => setNewStatus(s.value)} style={{
                  padding: '7px 14px', borderRadius: 99, fontSize: 13, fontWeight: 600,
                  border: `2px solid ${newStatus === s.value ? s.color : '#E4E4E7'}`,
                  background: newStatus === s.value ? s.color + '22' : 'white',
                  color: newStatus === s.value ? s.color : '#71717A',
                  cursor: 'pointer',
                }}>{s.label}</button>
              ))}
            </div>
            <button
              onClick={handleSave}
              disabled={saving}
              style={{
                padding: '10px 20px', background: '#33D633', color: 'white', border: 'none',
                borderRadius: 10, fontSize: 14, fontWeight: 700, cursor: 'pointer',
                opacity: saving ? 0.5 : 1,
              }}
            >
              {saving ? 'Сохранение...' : 'Сохранить'}
            </button>
          </div>
        </Modal>
      )}
    </PageShell>
  )
}

function Tab({ label, active, onClick, color }) {
  return (
    <button onClick={onClick} style={{
      padding: '7px 14px', borderRadius: 99, fontSize: 13, fontWeight: 600,
      border: `1.5px solid ${active ? (color || '#0F0F0D') : '#E4E4E7'}`,
      background: active ? (color ? color + '22' : '#0F0F0D') : 'white',
      color: active ? (color || 'white') : '#71717A',
      cursor: 'pointer',
    }}>{label}</button>
  )
}

function Info({ label, value }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div style={{ fontSize: 12, color: '#A1A1AA', fontWeight: 500 }}>{label}</div>
      <div style={{ fontSize: 14, fontWeight: 600, color: '#0F0F0D' }}>{value}</div>
    </div>
  )
}
