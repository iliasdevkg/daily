import { useState, useEffect } from 'react'
import { api } from '../api.js'
import Icon from '../components/Icon.jsx'

export default function History() {
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.getOrders()
      .then(data => setOrders(data.filter(o => o.status === 'delivered' || o.status === 'completed')))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  const total = orders.reduce((s, o) => s + parseFloat(o.total || 0), 0)
  const safePad = 'max(env(safe-area-inset-top,16px),16px)'

  return (
    <div style={{ padding: `${safePad} 16px 24px` }} className="no-sb">
      <div style={{ fontSize: 12, color: '#38BDF8', fontWeight: 700, letterSpacing: .8, textTransform: 'uppercase', marginBottom: 4 }}>/ история</div>
      <div style={{ fontSize: 26, fontWeight: 900, color: '#F4F4F5', letterSpacing: -1, marginBottom: 20 }}>История доставок</div>

      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 24 }}>
        <div style={{ background: '#18181B', borderRadius: 20, border: '1px solid rgba(255,255,255,.06)', padding: 16 }}>
          <div style={{ fontSize: 28, fontWeight: 900, color: '#33D633', letterSpacing: -1 }}>{orders.length}</div>
          <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>Доставлено</div>
        </div>
        <div style={{ background: '#18181B', borderRadius: 20, border: '1px solid rgba(255,255,255,.06)', padding: 16 }}>
          <div style={{ fontSize: 22, fontWeight: 900, color: '#FBBF24', letterSpacing: -1 }}>{total.toLocaleString()}</div>
          <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>Всего сом</div>
        </div>
      </div>

      {loading
        ? <div style={{ textAlign: 'center', padding: 40, color: '#52525B' }}>Загрузка...</div>
        : orders.length === 0
          ? (
            <div style={{ textAlign: 'center', padding: '60px 20px', color: '#52525B' }}>
              <Icon name="clipboardList" size={48} color="#3F3F46" style={{ marginBottom: 12 }} />
              <div style={{ fontSize: 15, fontWeight: 600, color: '#71717A' }}>История пуста</div>
            </div>
          )
          : orders.map(o => (
            <div key={o.id} style={{ background: '#18181B', borderRadius: 20, border: '1px solid rgba(255,255,255,.06)', padding: 16, marginBottom: 10 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                <div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: '#F4F4F5' }}>{o.customer_name || `Заказ #${o.id}`}</div>
                  <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>#{o.id} · {new Date(o.created_at).toLocaleDateString('ru')}</div>
                </div>
                <div>
                  <span style={{ padding: '4px 10px', borderRadius: 99, background: '#33D633' + '22', color: '#33D633', fontSize: 11, fontWeight: 700, display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <Icon name="checkCircle" size={12} /> Доставлено
                  </span>
                </div>
              </div>
              <div style={{ fontSize: 13, color: '#A1A1AA', marginBottom: 6, display: 'flex', alignItems: 'center', gap: 6 }}><Icon name="mapPin" size={14} color="#A1A1AA" /> {o.address}</div>
              <div style={{ fontSize: 14, fontWeight: 700, color: '#F4F4F5' }}>{parseFloat(o.total).toLocaleString()} сом</div>
            </div>
          ))
      }
    </div>
  )
}
