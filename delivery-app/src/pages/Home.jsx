import { useState, useEffect, useRef } from 'react'
import { api, subscribeToOrderEvents } from '../api.js'
import Icon from '../components/Icon.jsx'

const STATUS = {
  pending:   { label: 'В ожидании',  color: '#FBBF24' },
  confirmed: { label: 'Подтверждён', color: '#38BDF8' },
  packing:   { label: 'Собирается',  color: '#C084FC' },
  transit:   { label: 'В пути',      color: '#FB923C' },
  delivered: { label: 'Доставлен',   color: '#33D633' },
  cancelled: { label: 'Отменён',     color: '#EF4444' },
}

export default function Home({ user }) {
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState(null)
  const [updating, setUpdating] = useState(false)
  const [sheetOpen, setSheetOpen] = useState(false)

  async function load() {
    try { setOrders(await api.getOrders()) }
    catch {}
    finally { setLoading(false) }
  }

  useEffect(() => {
    load()
    const unsubscribe = subscribeToOrderEvents(load)
    return unsubscribe
  }, [])

  async function accept(order) {
    setUpdating(true)
    try {
      await api.updateStatus(order.id, 'transit', user.id)
      await load()
      setSelected(prev => prev ? { ...prev, status: 'transit', delivery_user_id: user.id } : null)
    } finally { setUpdating(false) }
  }

  async function deliver(order) {
    setUpdating(true)
    try {
      await api.updateStatus(order.id, 'delivered')
      await load()
      setSheetOpen(false)
      setSelected(null)
    } finally { setUpdating(false) }
  }

  function openOrder(o) { setSelected(o); setSheetOpen(true) }
  function closeSheet() { setSheetOpen(false); setTimeout(() => setSelected(null), 400) }

  const available = orders.filter(o => o.status === 'transit' && !o.delivery_user_id)
  const mine = orders.filter(o => o.delivery_user_id === user?.id && o.status === 'transit')
  const safePad = 'max(env(safe-area-inset-top,16px),16px)'

  return (
    <>
      <div style={{ padding: `${safePad} 16px 24px` }} className="no-sb">
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
          <div>
            <div style={{ fontSize: 12, color: '#38BDF8', fontWeight: 700, letterSpacing: .8, textTransform: 'uppercase', marginBottom: 4 }}>/ доставщик</div>
            <div style={{ fontSize: 26, fontWeight: 900, color: '#F4F4F5', letterSpacing: -1 }}>Заказы</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 14px', background: 'rgba(56,189,248,.12)', borderRadius: 99, border: '1px solid rgba(56,189,248,.25)' }}>
            <div className="pulse" style={{ width: 7, height: 7, borderRadius: '50%', background: '#38BDF8' }} />
            <span style={{ fontSize: 12, fontWeight: 600, color: '#38BDF8' }}>Онлайн</span>
          </div>
        </div>

        {/* Stats */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 24 }}>
          <StatCard icon="bike" label="Мои в пути" value={mine.length} color="#38BDF8" />
          <StatCard icon="package" label="Готовы к доставке" value={available.length} color="#FBBF24" />
        </div>

        {/* My active deliveries */}
        {mine.length > 0 && (
          <Section title="Мои заказы" sub={`${mine.length} в пути`} color="#38BDF8">
            {mine.map(o => <OrderCard key={o.id} order={o} badge="У меня" badgeColor="#38BDF8" onClick={() => openOrder(o)} onDeliver={deliver} />)}
          </Section>
        )}

        {/* Available */}
        <Section title="Готовы к доставке" sub={`${available.length} заказов`} color="#FBBF24">
          {loading
            ? <Skeleton />
            : available.length === 0
              ? <Empty text="Нет заказов для доставки" />
              : available.map(o => <OrderCard key={o.id} order={o} onClick={() => openOrder(o)} onAccept={accept} />)
          }
        </Section>
      </div>

      {/* Order Detail Sheet */}
      <div className={`sheet-bg${sheetOpen ? ' open' : ''}`} onClick={closeSheet} />
      <div className={`bottom-sheet${sheetOpen ? ' open' : ''}`}>
        <div style={{ width: 44, height: 4, background: 'rgba(255,255,255,.15)', borderRadius: 99, margin: '10px auto 0', flexShrink: 0 }} />
        {selected && (
          <div style={{ flex: 1, overflow: 'auto', padding: 20 }} className="no-sb">
            <div style={{ fontSize: 12, color: '#38BDF8', fontWeight: 700, letterSpacing: .6, textTransform: 'uppercase', marginBottom: 6 }}>/ заказ #{selected.id}</div>
            <div style={{ fontSize: 22, fontWeight: 800, color: '#F4F4F5', marginBottom: 20 }}>{selected.customer_name || 'Клиент'}</div>

            <InfoRow icon="mapPin" label="Адрес" value={selected.address} />
            <InfoRow icon="phone" label="Телефон" value={selected.customer_phone || '—'} />
            <InfoRow icon="wallet" label="Сумма" value={`${parseFloat(selected.total).toLocaleString()} сом`} />
            {selected.note && <InfoRow icon="pencil" label="Примечание" value={selected.note} />}

            {/* Items */}
            {selected.items?.[0]?.name && (
              <div style={{ marginTop: 16, marginBottom: 20 }}>
                <div style={{ fontSize: 12, color: '#71717A', fontWeight: 600, marginBottom: 10 }}>ТОВАРЫ</div>
                {selected.items.map((item, i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 14px', background: 'rgba(255,255,255,.04)', borderRadius: 12, marginBottom: 6, fontSize: 14 }}>
                    <span style={{ color: '#D4D4D8' }}>{item.name} × {item.quantity}</span>
                    <span style={{ fontWeight: 700, color: '#F4F4F5' }}>{(item.price * item.quantity).toLocaleString()} с</span>
                  </div>
                ))}
              </div>
            )}

            {/* Actions */}
            {selected.status === 'transit' && !selected.delivery_user_id && (
              <button className="btn-primary" onClick={() => accept(selected)} disabled={updating}>
                {updating ? 'Принятие...' : (
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                    <Icon name="checkCircle" size={18} /> Принять
                  </span>
                )}
              </button>
            )}
            {selected.status === 'transit' && selected.delivery_user_id === user?.id && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                <a href={`tel:${selected.customer_phone}`} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: 14, background: 'rgba(56,189,248,.15)', border: '1px solid rgba(56,189,248,.3)', borderRadius: 16, textAlign: 'center', color: '#38BDF8', fontWeight: 700, fontSize: 15, textDecoration: 'none' }}>
                  <Icon name="phone" size={17} /> Позвонить клиенту
                </a>
                <button className="btn-primary" onClick={() => deliver(selected)} disabled={updating}
                  style={{ background: '#33D633', color: 'white' }}>
                  {updating ? 'Обновление...' : (
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
                      <Icon name="flag" size={18} /> Доставлено!
                    </span>
                  )}
                </button>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  )
}

function StatCard({ icon, label, value, color }) {
  return (
    <div className="card" style={{ padding: 16 }}>
      <Icon name={icon} size={24} color={color} style={{ marginBottom: 8 }} />
      <div style={{ fontSize: 28, fontWeight: 900, color, letterSpacing: -1 }}>{value}</div>
      <div style={{ fontSize: 11, color: '#71717A', marginTop: 2 }}>{label}</div>
    </div>
  )
}

function Section({ title, sub, color, children }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 12 }}>
        <div style={{ fontSize: 16, fontWeight: 800, color: '#F4F4F5' }}>{title}</div>
        <div style={{ fontSize: 12, color }}>{sub}</div>
      </div>
      {children}
    </div>
  )
}

// CHANGED: swipe-to-accept / swipe-to-deliver. onAccept => swipe right reveals
// a green "Принять" action; onDeliver => swipe left reveals "Доставлено".
// A short drag (<6px) still falls through to onClick (open detail sheet) so
// tapping the card works exactly as before.
const SWIPE_TRIGGER_PX = 72
const SWIPE_MAX_PX = 96

function OrderCard({ order, badge, badgeColor, onClick, onAccept, onDeliver }) {
  const s = STATUS[order.status] || STATUS.pending
  const swipeDir = onDeliver ? 'left' : onAccept ? 'right' : null
  const [dx, setDx] = useState(0)
  const draggingRef = useRef(false)
  const startXRef = useRef(0)
  // CHANGED: tracks drag distance in a ref (not state) because the browser
  // fires a trailing synthetic `click` after pointerup — by then React may
  // have already re-rendered with dx reset to 0, so a state-based guard lets
  // the click through even after a real swipe. The ref survives that.
  const maxDragRef = useRef(0)

  function onPointerDown(e) {
    if (!swipeDir) return
    draggingRef.current = true
    startXRef.current = e.clientX
    maxDragRef.current = 0
  }
  function onPointerMove(e) {
    if (!draggingRef.current) return
    const delta = e.clientX - startXRef.current
    maxDragRef.current = Math.max(maxDragRef.current, Math.abs(delta))
    setDx(swipeDir === 'left' ? Math.min(0, Math.max(delta, -SWIPE_MAX_PX)) : Math.max(0, Math.min(delta, SWIPE_MAX_PX)))
  }
  function onPointerUp() {
    if (!draggingRef.current) return
    draggingRef.current = false
    if (Math.abs(dx) > SWIPE_TRIGGER_PX) {
      if (swipeDir === 'left') onDeliver(order)
      else onAccept(order)
    }
    setDx(0)
  }
  function handleClick() {
    if (maxDragRef.current < 6) onClick()
  }

  return (
    <div style={{ position: 'relative', marginBottom: 10, borderRadius: 20, overflow: 'hidden' }}>
      {swipeDir && (
        <div style={{
          position: 'absolute', inset: 0, display: 'flex', alignItems: 'center',
          justifyContent: swipeDir === 'left' ? 'flex-end' : 'flex-start',
          padding: '0 22px', fontSize: 13, fontWeight: 800, color: '#0A0A0F',
          background: swipeDir === 'left' ? '#33D633' : '#38BDF8',
        }}>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <Icon name={swipeDir === 'left' ? 'flag' : 'checkCircle'} size={15} />
            {swipeDir === 'left' ? 'Доставлено' : 'Принять'}
          </span>
        </div>
      )}
      <div
        className="card"
        onClick={handleClick}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        style={{
          padding: 16, cursor: 'pointer', position: 'relative', background: '#18181B',
          transform: `translateX(${dx}px)`,
          transition: draggingRef.current ? 'none' : 'transform 220ms ease',
          touchAction: 'pan-y',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 10 }}>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700, color: '#F4F4F5' }}>{order.customer_name || `Заказ #${order.id}`}</div>
            <div style={{ fontSize: 12, color: '#71717A', marginTop: 2 }}>#{order.id} · {parseFloat(order.total).toLocaleString()} сом</div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {badge && <span style={{ padding: '4px 10px', borderRadius: 99, background: badgeColor + '22', color: badgeColor, fontSize: 11, fontWeight: 700 }}>{badge}</span>}
            <span style={{ padding: '4px 10px', borderRadius: 99, background: s.color + '22', color: s.color, fontSize: 11, fontWeight: 700 }}>{s.label}</span>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: '#A1A1AA' }}>
          <Icon name="mapPin" size={14} color="#71717A" />
          <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{order.address}</span>
        </div>
      </div>
    </div>
  )
}

function InfoRow({ icon, label, value }) {
  return (
    <div style={{ display: 'flex', gap: 12, marginBottom: 14, alignItems: 'flex-start' }}>
      <Icon name={icon} size={18} color="#71717A" style={{ marginTop: 2 }} />
      <div>
        <div style={{ fontSize: 11, color: '#71717A', fontWeight: 600, marginBottom: 2 }}>{label}</div>
        <div style={{ fontSize: 14, color: '#F4F4F5', fontWeight: 500 }}>{value}</div>
      </div>
    </div>
  )
}

function Skeleton() {
  return [1, 2].map(i => (
    <div key={i} className="card" style={{ padding: 16, marginBottom: 10, opacity: .4 }}>
      <div style={{ height: 14, background: 'rgba(255,255,255,.1)', borderRadius: 8, marginBottom: 8, width: '60%' }} />
      <div style={{ height: 11, background: 'rgba(255,255,255,.06)', borderRadius: 8, width: '40%' }} />
    </div>
  ))
}

function Empty({ text }) {
  return (
    <div style={{ textAlign: 'center', padding: '40px 20px', color: '#52525B' }}>
      <Icon name="inbox" size={44} color="#3F3F46" style={{ marginBottom: 12 }} />
      <div style={{ fontSize: 14, fontWeight: 600 }}>{text}</div>
    </div>
  )
}
