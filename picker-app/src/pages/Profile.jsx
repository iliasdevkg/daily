import Icon from '../components/Icon.jsx'

export default function Profile({ user, onLogout }) {
  const safePad = 'max(env(safe-area-inset-top,16px),16px)'
  return (
    <div style={{ padding: `${safePad} 16px 24px` }}>
      <div style={{ fontSize: 12, color: '#FB923C', fontWeight: 700, letterSpacing: .8, textTransform: 'uppercase', marginBottom: 4 }}>/ профиль</div>
      <div style={{ fontSize: 26, fontWeight: 900, color: '#F4F4F5', letterSpacing: -1, marginBottom: 24 }}>Профиль</div>

      <div style={{ background: 'linear-gradient(135deg,rgba(251,146,60,.12),rgba(251,146,60,.04))', borderRadius: 24, border: '1px solid rgba(251,146,60,.2)', padding: 20, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 16 }}>
        <div style={{ width: 64, height: 64, borderRadius: '50%', background: 'rgba(251,146,60,.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}><Icon name="package" size={30} color="#FB923C" /></div>
        <div>
          <div style={{ fontSize: 20, fontWeight: 800, color: '#F4F4F5' }}>{user?.name || 'Сборщик'}</div>
          <div style={{ fontSize: 13, color: '#71717A', marginTop: 2 }}>{user?.email}</div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 8, padding: '4px 10px', background: 'rgba(251,146,60,.15)', borderRadius: 99 }}>
            <div style={{ width: 6, height: 6, background: '#FB923C', borderRadius: '50%' }} />
            <span style={{ fontSize: 11, fontWeight: 700, color: '#FB923C' }}>Сборщик</span>
          </div>
        </div>
      </div>

      {[
        { icon: 'phone', title: 'Контакты', sub: user?.phone || '+996 — — —' },
        { icon: 'store', title: 'Склад', sub: 'Склад Бишкек' },
        { icon: 'sliders', title: 'Настройки', sub: 'Уведомления, язык' },
        { icon: 'helpCircle', title: 'Помощь', sub: 'Служба поддержки' },
      ].map(item => (
        <div key={item.title} style={{ background: '#18181B', borderRadius: 16, border: '1px solid rgba(255,255,255,.06)', padding: 14, display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
          <div style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(255,255,255,.05)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={item.icon} size={19} color="#D4D4D8" /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600, color: '#F4F4F5' }}>{item.title}</div>
            <div style={{ fontSize: 12, color: '#71717A' }}>{item.sub}</div>
          </div>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#52525B" strokeWidth="2.5" strokeLinecap="round"><polyline points="9 18 15 12 9 6"/></svg>
        </div>
      ))}

      <button onClick={onLogout} style={{ width: '100%', marginTop: 8, padding: 14, background: 'rgba(239,68,68,.1)', border: '1px solid rgba(239,68,68,.2)', borderRadius: 16, color: '#FCA5A5', fontSize: 14, fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
        <Icon name="logout" size={18} /> Выйти
      </button>
    </div>
  )
}
