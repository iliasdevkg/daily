import { useState } from 'react'
import { api } from '../api.js'

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('admin@delivery.com')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const data = await api.login(email, password)
      if (data.user.role !== 'admin') {
        setError('У вас нет прав администратора')
        return
      }
      onLogin(data.token)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{
      minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: '#0F0F0D',
    }}>
      <div style={{
        width: 400, background: '#18181B', borderRadius: 24, padding: 40,
        border: '1px solid #27272A',
      }}>
        {/* Logo */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 32 }}>
          <div style={{
            width: 44, height: 44, background: '#33D633', borderRadius: 12,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 22, fontWeight: 900, color: 'white',
          }}>D</div>
          <div>
            <div style={{ fontSize: 20, fontWeight: 800, color: 'white' }}>Daily Admin</div>
            <div style={{ fontSize: 13, color: '#52525B' }}>Панель управления</div>
          </div>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div>
            <label style={{ fontSize: 13, fontWeight: 600, color: '#A1A1AA', display: 'block', marginBottom: 6 }}>
              Email
            </label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              required
              style={{
                width: '100%', padding: '12px 14px', background: '#27272A',
                border: '1.5px solid #3F3F46', borderRadius: 12, color: 'white',
                fontSize: 15, outline: 'none',
              }}
              onFocus={e => e.target.style.borderColor = '#33D633'}
              onBlur={e => e.target.style.borderColor = '#3F3F46'}
            />
          </div>

          <div>
            <label style={{ fontSize: 13, fontWeight: 600, color: '#A1A1AA', display: 'block', marginBottom: 6 }}>
              Пароль
            </label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              style={{
                width: '100%', padding: '12px 14px', background: '#27272A',
                border: '1.5px solid #3F3F46', borderRadius: 12, color: 'white',
                fontSize: 15, outline: 'none',
              }}
              onFocus={e => e.target.style.borderColor = '#33D633'}
              onBlur={e => e.target.style.borderColor = '#3F3F46'}
            />
          </div>

          {error && (
            <div style={{
              padding: '10px 14px', background: 'rgba(239,68,68,.15)',
              border: '1px solid rgba(239,68,68,.3)', borderRadius: 10,
              color: '#FCA5A5', fontSize: 14,
            }}>{error}</div>
          )}

          <button
            type="submit"
            disabled={loading}
            style={{
              padding: '14px', background: loading ? '#15803D' : '#33D633',
              border: 'none', borderRadius: 12, fontSize: 15, fontWeight: 700,
              color: 'white', marginTop: 4, transition: 'background 200ms',
              opacity: loading ? 0.7 : 1,
            }}
          >
            {loading ? 'Вход...' : 'Войти'}
          </button>
        </form>
      </div>
    </div>
  )
}
