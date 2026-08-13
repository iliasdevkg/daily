import { useState, useEffect } from 'react'
import { api } from '../api.js'
import Icon from '../components/Icon.jsx'

export default function History() {
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    api.getOrders()
      .then(data => setOrders(data.filter(o => o.status === 'transit' || o.status === 'delivered' || o.status === 'completed')))
      .catch(() => {})
      .finally(() => setLoading(false))
  }, [])

  const packed = orders.filter(o => o.status === 'transit' || o.status === 'delivered' || o.status === 'completed')
  const totalItems = packed.reduce((s, o) => s + (o.items?.filter(i => i.name)?.length || 0), 0)
  const safePad = 'max(env(safe-area-inset-top,16px),16px)'

  return (
    <div style={{ padding: `${safePad} 16px 24px` }} className="no-sb">
      <div style={{ fontSize: 12, color: '#FB923C', fontWeight: 700, letterSpacing: .8, textTransform: 'uppercase', marginBottom: 4 }}>/ история</div>
      <div style={{ fontSize: 26, fontWeight: 900, color: '#F4F4F5', letterSpacing: -1, marginBottom: 20 }}>История сборки</div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 24 }}>
        <div style={{ background: '#18181B', borderRadius: 20, border: '1px solid rgba(255,255,255,.06)', padding: 16 }}>
          <div style={{ fontSize: 28, fontWeight: 900, color: '#FB923C', letterSpacing: -1 }}>{packed.length}</div>
          <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>Собрано</div>
        </div>
        <div style={{ background: '#18181B', borderRadius: 20, border: '1px solid rgba(255,255,255,.06)', padding: 16 }}>
          <div style={{ fontSize: 28, fontWeight: 900, color: '#FBBF24', letterSpacing: -1 }}>{totalItems}</div>
          <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>Кол-во товаров</div>
        </div>
      </div>

      {loading
        ? <div style={{ textAlign: 'center', padding: 40, color: '#52525B' }}>Загрузка...</div>
        : packed.length === 0
          ? (
            <div style={{ textAlign: 'center', padding: '60px 20px', color: '#52525B' }}>
              <Icon name="clipboardList" size={48} color="#3F3F46" style={{ marginBottom: 12 }} />
              <div style={{ fontSize: 15, fontWeight: 600, color: '#71717A' }}>История пуста</div>
            </div>
          )
          : packed.map(o => {
            const itemCount = o.items?.filter(i => i.name)?.length || 0
            const isDelivered = o.status === 'delivered' || o.status === 'completed'
            return (
              <div key={o.id} style={{ background: '#18181B', borderRadius: 20, border: '1px solid rgba(255,255,255,.06)', padding: 16, marginBottom: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                  <div>
                    <div style={{ fontSize: 15, fontWeight: 700, color: '#F4F4F5' }}>{o.customer_name || `Заказ #${o.id}`}</div>
                    <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>#{o.id} · {new Date(o.created_at).toLocaleDateString('ru')}</div>
                  </div>
                  <span style={{ padding: '4px 10px', borderRadius: 99, background: (isDelivered ? '#33D633' : '#FB923C') + '22', color: isDelivered ? '#33D633' : '#FB923C', fontSize: 11, fontWeight: 700, alignSelf: 'flex-start', display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <Icon name={isDelivered ? 'checkCircle' : 'truck'} size={12} /> {isDelivered ? 'Доставлено' : 'В пути'}
                  </span>
                </div>
                <div style={{ fontSize: 13, color: '#A1A1AA', display: 'flex', alignItems: 'center', gap: 6 }}><Icon name="package" size={14} color="#A1A1AA" /> {itemCount} товаров собрано</div>
              </div>
            )
          })
      }
    </div>
  )
}
