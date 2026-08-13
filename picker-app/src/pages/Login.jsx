import { useState } from 'react'
import { api } from '../api.js'
import Icon from '../components/Icon.jsx'

export default function Login({ onLogin }) {
  const [email, setEmail] = useState('picker@daily.kg')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function handleSubmit(e) {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const data = await api.login(email, password)
      if (data.user.role !== 'picker') {
        setError('Этот вход только для сборщиков')
        return
      }
      onLogin(data.token, data.user)
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ minHeight: '100dvh', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#0A0A0F', padding: 20 }}>
      <div style={{ position: 'fixed', top: -100, left: -100, width: 400, height: 400, borderRadius: '50%', background: '#FB923C', opacity: .06, filter: 'blur(80px)', pointerEvents: 'none' }} />

      <div style={{ width: '100%', maxWidth: 380 }}>
        <div style={{ textAlign: 'center', marginBottom: 36 }}>
          <div style={{ width: 64, height: 64, background: 'linear-gradient(135deg,#FB923C,#EA580C)', borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px', boxShadow: '0 8px 24px rgba(251,146,60,.35)' }}>
            <Icon name="package" size={30} color="white" />
          </div>
          <div style={{ fontSize: 22, fontWeight: 800, color: '#F4F4F5', letterSpacing: -0.5 }}>Daily Сборщик</div>
          <div style={{ fontSize: 13, color: '#52525B', marginTop: 4 }}>Платформа для сборщиков</div>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div>
            <label style={{ fontSize: 12, fontWeight: 600, color: '#71717A', display: 'block', marginBottom: 6 }}>Email</label>
            <input className="inp" type="email" value={email} onChange={e => setEmail(e.target.value)} required />
          </div>
          <div>
            <label style={{ fontSize: 12, fontWeight: 600, color: '#71717A', display: 'block', marginBottom: 6 }}>Пароль</label>
            <input className="inp" type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" required />
          </div>
          {error && (
            <div style={{ padding: '10px 14px', background: 'rgba(239,68,68,.15)', borderRadius: 12, color: '#FCA5A5', fontSize: 13, border: '1px solid rgba(239,68,68,.25)' }}>
              {error}
            </div>
          )}
          <button className="btn-primary" type="submit" disabled={loading} style={{ marginTop: 4, opacity: loading ? .6 : 1 }}>
            {loading ? 'Вход...' : 'Войти →'}
          </button>
        </form>

        <div style={{ marginTop: 24, padding: 16, background: 'rgba(251,146,60,.08)', borderRadius: 16, border: '1px solid rgba(251,146,60,.15)' }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: '#FB923C', marginBottom: 6 }}>Demo вход:</div>
          <div style={{ fontSize: 12, color: '#71717A' }}>Email: picker@daily.kg</div>
          <div style={{ fontSize: 12, color: '#71717A' }}>Пароль: password</div>
        </div>
      </div>
    </div>
  )
}
