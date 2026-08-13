import { useState, useEffect } from 'react'
import Login from './pages/Login.jsx'
import Home from './pages/Home.jsx'
import History from './pages/History.jsx'
import Profile from './pages/Profile.jsx'
import Icon from './components/Icon.jsx'

export default function App() {
  const [token, setToken] = useState(() => localStorage.getItem('delivery_token'))
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem('delivery_user') || 'null') } catch { return null }
  })
  const [tab, setTab] = useState(0)

  function onLogin(token, user) {
    localStorage.setItem('delivery_token', token)
    localStorage.setItem('delivery_user', JSON.stringify(user))
    setToken(token)
    setUser(user)
  }
  function onLogout() {
    localStorage.removeItem('delivery_token')
    localStorage.removeItem('delivery_user')
    setToken(null)
    setUser(null)
  }

  if (!token) return <Login onLogin={onLogin} />

  return (
    <div className="m-app">
      <div className="tab-area">
        <div className={`tab-view${tab === 0 ? ' active' : ''}`}>
          <Home user={user} />
        </div>
        <div className={`tab-view${tab === 1 ? ' active' : ''}`}>
          <History />
        </div>
        <div className={`tab-view${tab === 2 ? ' active' : ''}`}>
          <Profile user={user} onLogout={onLogout} />
        </div>
      </div>

      {/* Bottom Nav */}
      <div className="m-nav-wrap">
        <div className="glass" style={{ borderRadius: 28, padding: 6, display: 'flex', gap: 4, boxShadow: '0 8px 32px rgba(0,0,0,.4)' }}>
          <NavBtn icon="home" label="Активные" active={tab === 0} onClick={() => setTab(0)} />
          <NavBtn icon="clipboardList" label="История" active={tab === 1} onClick={() => setTab(1)} />
          <NavBtn icon="user" label="Профиль" active={tab === 2} onClick={() => setTab(2)} />
        </div>
      </div>
    </div>
  )
}

function NavBtn({ icon, label, active, onClick }) {
  return (
    <button className={`nav-btn${active ? ' active' : ''}`} onClick={onClick}>
      <Icon name={icon} size={20} />
      <span className="nav-lbl">{label}</span>
    </button>
  )
}
