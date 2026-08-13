const BASE = '/api'

function getToken() { return localStorage.getItem('picker_token') }

async function req(method, path, body) {
  const headers = { 'Content-Type': 'application/json' }
  const token = getToken()
  if (token) headers['Authorization'] = `Bearer ${token}`
  const res = await fetch(`${BASE}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined })
  const data = await res.json()
  if (!res.ok) throw new Error(data.message || data.error || 'Ошибка')
  return data
}

// Real-time order updates over Server-Sent Events, replacing 30s polling.
// EventSource can't send an Authorization header, so the token rides in
// the query string instead. Call the returned function to unsubscribe.
export function subscribeToOrderEvents(onOrderChange) {
  const token = getToken()
  if (!token) return () => {}
  const es = new EventSource(`${BASE}/events?token=${encodeURIComponent(token)}`)
  es.addEventListener('order', () => onOrderChange())
  return () => es.close()
}

export const api = {
  login: (email, password) => req('POST', '/auth/login', { email, password }),
  getOrders: () => req('GET', '/orders/picker'),
  updateStatus: (id, status, picker_user_id) =>
    req('PATCH', `/orders/${id}/status`, { status, picker_user_id }),
  getProfile: () => req('GET', '/users/profile'),
}
