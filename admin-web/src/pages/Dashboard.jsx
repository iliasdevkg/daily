import { useState, useEffect, useMemo } from 'react'
import { api, subscribeToOrderEvents } from '../api.js'
import Icon from '../components/Icon.jsx'

const STATUS_LABEL = {
  pending: 'В ожидании', confirmed: 'Подтверждён', packing: 'Собирается',
  transit: 'В пути', delivered: 'Доставлен', completed: 'Завершён', cancelled: 'Отменён',
}
const STATUS_COLOR = {
  pending: '#D97706', confirmed: '#0284C7', packing: '#9333EA',
  transit: '#EA580C', delivered: '#16A34A', completed: '#15803D', cancelled: '#DC2626',
}

function StatCard({ icon, label, value, color, sub }) {
  return (
    <div className="card" style={{ padding: 22, display: 'flex', flexDirection: 'column', gap: 8 }}>
      <div style={{
        width: 44, height: 44, background: color + '1A', borderRadius: 12, color,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}><Icon name={icon} size={22} /></div>
      <div style={{ fontSize: 13, color: 'var(--text-2)', fontWeight: 500 }}>{label}</div>
      <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: -1 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, color: 'var(--text-3)' }}>{sub}</div>}
    </div>
  )
}

// Столбчатый график заказов за последние 14 дней (одна серия — легенда не нужна,
// заголовок карточки называет её; ховер-тултип несёт точные значения).
function OrdersChart({ orders }) {
  const [hover, setHover] = useState(null)

  const days = useMemo(() => {
    const result = []
    const now = new Date()
    for (let i = 13; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i)
      const next = new Date(d); next.setDate(d.getDate() + 1)
      const dayOrders = orders.filter(o => {
        const t = new Date(o.created_at)
        return t >= d && t < next
      })
      result.push({
        date: d,
        label: d.toLocaleDateString('ru', { day: 'numeric', month: 'short' }).replace('.', ''),
        count: dayOrders.length,
        revenue: dayOrders.reduce((s, o) => s + parseFloat(o.total || 0), 0),
      })
    }
    return result
  }, [orders])

  const W = 720, H = 230, padL = 34, padR = 8, padT = 14, padB = 28
  const plotW = W - padL - padR, plotH = H - padT - padB
  const rawMax = Math.max(1, ...days.map(d => d.count))
  // Чистый максимум оси: 1-2-5 × 10^k
  const pow = Math.pow(10, Math.floor(Math.log10(rawMax)))
  const yMax = [1, 2, 5, 10].map(m => m * pow).find(m => m >= rawMax) || rawMax
  const ticks = [0, yMax / 2, yMax].map(v => Math.round(v * 10) / 10)

  const band = plotW / days.length
  const barW = Math.min(24, band * 0.55)
  const maxIdx = days.reduce((best, d, i) => (d.count > days[best].count ? i : best), 0)

  // Столбик: скруглённый верх (4px), прямое основание
  function barPath(x, y, w, h) {
    const r = Math.min(4, h)
    if (h <= 0) return ''
    return `M${x},${y + h} L${x},${y + r} Q${x},${y} ${x + r},${y} L${x + w - r},${y} Q${x + w},${y} ${x + w},${y + r} L${x + w},${y + h} Z`
  }

  return (
    <div className="card" style={{ padding: '20px 22px', position: 'relative' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <div style={{ fontSize: 16, fontWeight: 700 }}>Заказы за 14 дней</div>
        <div style={{ fontSize: 13, color: 'var(--text-2)' }}>
          всего <span style={{ fontWeight: 700, color: 'var(--text-1)' }}>{days.reduce((s, d) => s + d.count, 0)}</span>
        </div>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <svg viewBox={`0 0 ${W} ${H}`} style={{ width: '100%', minWidth: 480, display: 'block' }}
             onMouseLeave={() => setHover(null)}>
          {/* Сетка + подписи оси Y */}
          {ticks.map(t => {
            const y = padT + plotH - (t / yMax) * plotH
            return (
              <g key={t}>
                <line x1={padL} x2={W - padR} y1={y} y2={y} stroke="#E7E6E0" strokeWidth="1" />
                <text x={padL - 8} y={y + 4} textAnchor="end" fontSize="11" fill="#898781">{t}</text>
              </g>
            )
          })}

          {/* Столбики */}
          {days.map((d, i) => {
            const h = (d.count / yMax) * plotH
            const x = padL + i * band + (band - barW) / 2
            const y = padT + plotH - h
            return (
              <g key={i}>
                <path d={barPath(x, y, barW, h)} fill={hover === i ? '#178A31' : '#1FA83C'} />
                {/* Прямая подпись только у максимума — остальное несут ось и тултип */}
                {i === maxIdx && d.count > 0 && (
                  <text x={x + barW / 2} y={y - 6} textAnchor="middle" fontSize="11" fontWeight="700" fill="#0F0F0D">
                    {d.count}
                  </text>
                )}
                {/* Подпись дня — каждый второй, чтобы не слипались */}
                {i % 2 === 1 && (
                  <text x={padL + i * band + band / 2} y={H - 8} textAnchor="middle" fontSize="10.5" fill="#898781">
                    {d.label}
                  </text>
                )}
                {/* Хит-зона на всю высоту — цель больше самой метки */}
                <rect x={padL + i * band} y={padT} width={band} height={plotH}
                      fill="transparent" onMouseEnter={() => setHover(i)} />
              </g>
            )
          })}

          {/* Базовая линия */}
          <line x1={padL} x2={W - padR} y1={padT + plotH} y2={padT + plotH} stroke="#C3C2B7" strokeWidth="1" />
        </svg>
      </div>

      {hover !== null && (
        <div style={{
          position: 'absolute', top: 14, right: 22, pointerEvents: 'none',
          background: '#0F0F0D', color: 'white', borderRadius: 10, padding: '8px 12px',
          fontSize: 12, lineHeight: 1.6, boxShadow: '0 4px 16px rgba(0,0,0,0.25)',
        }}>
          <div style={{ fontWeight: 700 }}>{days[hover].date.toLocaleDateString('ru', { day: 'numeric', month: 'long' })}</div>
          <div>Заказов: <b>{days[hover].count}</b></div>
          <div>Выручка: <b>{days[hover].revenue.toLocaleString()} сом</b></div>
        </div>
      )}
    </div>
  )
}

// "Сейчас чогулат / жолдо" — заказы в статусе packing (сборщик собирает) или
// transit (курьер везёт), с именем сотрудника и тем, сколько времени прошло
// с момента назначения. Данные уже есть в orders (picker_name/delivery_name
// из GET /orders) — отдельный запрос к бэкенду не нужен.
function InProgressPanel({ orders }) {
  const inProgress = orders.filter(o => o.status === 'packing' || o.status === 'transit')
  if (inProgress.length === 0) return null

  function since(o) {
    const mins = Math.max(0, Math.round((Date.now() - new Date(o.created_at)) / 60000))
    return mins < 1 ? 'только что' : `${mins} мин назад`
  }

  return (
    <div className="card" style={{ padding: '18px 22px', marginBottom: 20 }}>
      <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 12 }}>Сейчас в работе · {inProgress.length}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {inProgress.map(o => {
          const isPacking = o.status === 'packing'
          const employee = isPacking ? o.picker_name : o.delivery_name
          return (
            <div key={o.id} style={{
              display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
              padding: '10px 14px', background: '#FAFAF8', borderRadius: 12,
            }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ width: 8, height: 8, borderRadius: '50%', background: STATUS_COLOR[o.status], flexShrink: 0 }} />
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>
                    #{o.id} · {isPacking ? 'Собирает' : 'Везёт'} {employee ? `— ${employee}` : '(не назначен)'}
                  </div>
                  <div style={{ fontSize: 11.5, color: 'var(--text-3)' }}>{o.address}</div>
                </div>
              </div>
              <span style={{ fontSize: 11.5, color: 'var(--text-3)', whiteSpace: 'nowrap' }}>{since(o)}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

export default function Dashboard() {
  const [orders, setOrders] = useState([])
  const [products, setProducts] = useState([])
  const [users, setUsers] = useState([])
  const [earnings, setEarnings] = useState([])
  const [loading, setLoading] = useState(true)

  function load() {
    return Promise.all([api.getOrders(), api.getProducts(), api.getUsers(), api.getEarningsSummary().catch(() => [])])
      .then(([o, p, u, e]) => { setOrders(o); setProducts(p); setUsers(u); setEarnings(e) })
      .catch(() => {})
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    const unsubscribe = subscribeToOrderEvents(load)
    return unsubscribe
  }, [])

  const active = orders.filter(o => !['delivered', 'completed', 'cancelled'].includes(o.status))
  const revenue = orders.filter(o => o.status !== 'cancelled').reduce((s, o) => s + parseFloat(o.total || 0), 0)
  const today = new Date(); today.setHours(0, 0, 0, 0)
  const todayCount = orders.filter(o => new Date(o.created_at) >= today).length

  if (loading) return <PageShell title="Дашборд"><Spinner /></PageShell>

  return (
    <PageShell title="Дашборд">
      {/* Карточки-показатели */}
      <div className="dashboard-stats-grid" style={{ display: 'grid', gap: 16, marginBottom: 20 }}>
        <StatCard icon="wallet" label="Выручка (без отменённых)" value={`${revenue.toLocaleString()} сом`} color="#16A34A" />
        <StatCard icon="package" label="Всего заказов" value={orders.length} color="#0284C7" sub={`+${todayCount} сегодня`} />
        <StatCard icon="activity" label="Активные заказы" value={active.length} color="#EA580C" sub="в работе прямо сейчас" />
        <StatCard icon="users" label="Пользователи" value={users.length} color="#9333EA" sub={`${products.length} товаров в каталоге`} />
      </div>

      {/* График */}
      <div style={{ marginBottom: 20 }}>
        <OrdersChart orders={orders} />
      </div>

      {/* Разбивка по статусам */}
      <div className="card" style={{ padding: '16px 22px', marginBottom: 20, display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
        <span style={{ fontSize: 13, fontWeight: 700, marginRight: 4 }}>По статусам:</span>
        {Object.keys(STATUS_LABEL).map(s => {
          const cnt = orders.filter(o => o.status === s).length
          if (!cnt) return null
          return (
            <span key={s} style={{
              display: 'inline-flex', alignItems: 'center', gap: 6, padding: '5px 12px',
              borderRadius: 99, fontSize: 12.5, fontWeight: 600,
              background: STATUS_COLOR[s] + '14', color: STATUS_COLOR[s],
            }}>
              <span style={{ width: 7, height: 7, borderRadius: '50%', background: STATUS_COLOR[s] }} />
              {STATUS_LABEL[s]} · {cnt}
            </span>
          )
        })}
        {orders.length === 0 && <span style={{ fontSize: 13, color: 'var(--text-3)' }}>Заказов пока нет</span>}
      </div>

      {/* Live: заказы, которые прямо сейчас собираются или везутся — кто именно
          собирает/везёт и с какого момента, чтобы было видно "доставщик товар
          чогулуп жатат" без открытия карточки заказа. */}
      <InProgressPanel orders={orders} />

      {/* Выплаты сборщикам/курьерам — начисляются автоматически при доставке (earnings.js) */}
      {earnings.length > 0 && (
        <div className="card" style={{ padding: '18px 22px', marginBottom: 20 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 12 }}>Выплаты сотрудникам</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 10 }}>
            {earnings.map(e => (
              <div key={`${e.role}-${e.user_id}`} style={{
                display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                padding: '10px 14px', background: '#FAFAF8', borderRadius: 12,
              }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600 }}>{e.name}</div>
                  <div style={{ fontSize: 11, color: 'var(--text-3)' }}>
                    {e.role === 'picker' ? 'сборщик' : 'курьер'} · {e.orders} заказ.
                  </div>
                </div>
                <div style={{ fontSize: 14, fontWeight: 800, color: '#16A34A' }}>{Number(e.total).toLocaleString()} с</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Последние заказы */}
      <div className="card" style={{ overflow: 'hidden', overflowX: 'auto' }}>
        <div style={{ padding: '18px 22px', borderBottom: '1px solid var(--border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontSize: 16, fontWeight: 700 }}>Последние заказы</div>
          <div style={{ fontSize: 13, color: 'var(--text-2)' }}>
            <span style={{ fontWeight: 700, color: '#16A34A' }}>{orders.filter(o => o.status === 'delivered').length}</span> доставлено
          </div>
        </div>
        <table className="data-table" style={{ minWidth: 640 }}>
          <thead>
            <tr>
              {['ID', 'Клиент', 'Адрес', 'Сумма', 'Статус', 'Дата'].map(h => <th key={h}>{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {orders.slice(0, 10).map(o => (
              <tr key={o.id}>
                <td style={{ fontWeight: 700 }}>#{o.id}</td>
                <td>{o.customer_name || '—'}</td>
                <td style={{ color: 'var(--text-2)', maxWidth: 180, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{o.address}</td>
                <td style={{ fontWeight: 700 }}>{parseFloat(o.total).toLocaleString()} с</td>
                <td>
                  <span style={{
                    padding: '4px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600,
                    background: (STATUS_COLOR[o.status] || '#71717A') + '14',
                    color: STATUS_COLOR[o.status] || 'var(--text-2)',
                  }}>{STATUS_LABEL[o.status] || o.status}</span>
                </td>
                <td style={{ fontSize: 12, color: 'var(--text-3)' }}>
                  {new Date(o.created_at).toLocaleDateString('ru')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {orders.length === 0 && (
          <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-3)' }}>Нет заказов</div>
        )}
      </div>
    </PageShell>
  )
}

export function PageShell({ title, actions, children }) {
  return (
    <div style={{ padding: '28px 32px', maxWidth: 1240, margin: '0 auto' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 800, letterSpacing: -0.5 }}>{title}</h1>
        {actions}
      </div>
      {children}
    </div>
  )
}

export function Spinner() {
  return (
    <div style={{ textAlign: 'center', padding: 60, color: 'var(--text-3)' }}>Загрузка...</div>
  )
}
