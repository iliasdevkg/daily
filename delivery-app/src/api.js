const BASE = '/api'
const getToken = () => localStorage.getItem('delivery_token')

async function req(method, path, body) {
  const headers = { 'Content-Type': 'application/json' }
  const token = getToken()
  if (token) headers['Authorization'] = `Bearer ${token}`
  const res = await fetch(`${BASE}${path}`, {
    method, headers,
    body: body ? JSON.stringify(body) : undefined,
  })
  if (!res.ok) {
    const e = await res.json().catch(() => ({ message: res.statusText }))
    throw new Error(e.message || 'Ошибка')
  }
  return res.json()
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
  getOrders: () => req('GET', '/orders/delivery'),
  updateStatus: (id, status, delivery_user_id) =>
    req('PATCH', `/orders/${id}/status`, { status, delivery_user_id }),
  getProfile: () => req('GET', '/users/profile'),
}
