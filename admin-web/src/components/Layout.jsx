import { useState, useEffect } from 'react'
import { subscribeToOrderEvents } from '../api.js'
import Icon from './Icon.jsx'

const NAV = [
  { id: 'dashboard',  label: 'Дашборд', icon: 'dashboard' },
  { id: 'orders',     label: 'Заказы', icon: 'package' },
  { id: 'products',   label: 'Товары', icon: 'bag' },
  { id: 'purchasing', label: 'Закуп', icon: 'alert' },
  { id: 'categories', label: 'Категории', icon: 'folder' },
  { id: 'users',      label: 'Пользователи', icon: 'users' },
  { id: 'automation', label: 'Автоматизация', icon: 'zap' },
]

// Sidebar is a static flex column on tablet/desktop and a fixed off-canvas
// drawer toggled by a hamburger button below 768px (see index.css).
export default function Layout({ children, page, onNavigate, onLogout }) {
  const [mobileOpen, setMobileOpen] = useState(false)
  const [live, setLive] = useState(false)

  // Live-индикатор: пока SSE-поток открыт и приходят события — точка зелёная.
  useEffect(() => {
    setLive(true) // соединение открывается сразу; при ошибке EventSource сам переподключается
    const unsubscribe = subscribeToOrderEvents(() => setLive(true))
    return unsubscribe
  }, [])

  function navigate(id) {
    onNavigate(id)
    setMobileOpen(false)
  }

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden' }}>
      <div className={`admin-overlay${mobileOpen ? ' open' : ''}`} onClick={() => setMobileOpen(false)} />

      {/* Sidebar */}
      <aside className={`admin-sidebar${mobileOpen ? ' open' : ''}`} style={{
        width: 248, background: '#0F0F0D', display: 'flex', flexDirection: 'column',
        flexShrink: 0, padding: '24px 14px',
      }}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 8px 26px' }}>
          <div style={{
            width: 38, height: 38, background: 'linear-gradient(135deg, #33D633, #1FA83C)',
            borderRadius: 11, display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 18, fontWeight: 900, color: 'white', flexShrink: 0,
            boxShadow: '0 4px 12px rgba(51,214,51,0.35)',
          }}>D</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: 'white', lineHeight: 1.1 }}>Daily</div>
            <div style={{ fontSize: 11, color: '#71717A', fontWeight: 500 }}>Панель управления</div>
          </div>
          <span title={live ? 'Обновления в реальном времени' : 'Нет соединения'} style={{
            width: 9, height: 9, borderRadius: '50%', flexShrink: 0,
            background: live ? '#33D633' : '#52525B',
            boxShadow: live ? '0 0 0 3px rgba(51,214,51,0.25)' : 'none',
          }} />
        </div>

        {/* Nav */}
        <nav style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 3 }}>
          {NAV.map(item => (
            <button key={item.id} onClick={() => navigate(item.id)} className={`nav-item${page === item.id ? ' active' : ''}`} style={{
              display: 'flex', alignItems: 'center', gap: 11,
              padding: '10px 12px', borderRadius: 12, border: 'none',
              background: 'transparent',
              color: '#A1A1AA',
              fontSize: 14, fontWeight: 600, textAlign: 'left',
              transition: 'background 150ms, color 150ms',
              cursor: 'pointer', minHeight: 44,
            }}>
              <Icon name={item.icon} size={18} />
              {item.label}
            </button>
          ))}
        </nav>

        {/* Logout */}
        <button onClick={onLogout} className="nav-item" style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '10px 12px', borderRadius: 12, border: 'none',
          background: 'transparent', color: '#71717A', fontSize: 14,
          fontWeight: 600, cursor: 'pointer', minHeight: 44,
        }}>
          <Icon name="logout" size={18} /> Выйти
        </button>
      </aside>

      {/* Main */}
      <main style={{ flex: 1, overflow: 'auto', background: 'var(--bg)' }}>
        <button className="admin-hamburger" onClick={() => setMobileOpen(true)} aria-label="Меню">
          <Icon name="menu" size={20} />
        </button>
        {children}
      </main>
    </div>
  )
}
