const BASE = '/api'

function getToken() {
  return localStorage.getItem('admin_token')
}

async function request(method, path, body) {
  const headers = { 'Content-Type': 'application/json' }
  const token = getToken()
  if (token) headers['Authorization'] = `Bearer ${token}`

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({ message: res.statusText }))
    throw new Error(err.message || 'Произошла ошибка')
  }

  return res.json()
}

// Real-time order updates over Server-Sent Events, replacing 30s polling.
// EventSource can't send an Authorization header, so the token rides in
// the query string instead. Call the returned function to unsubscribe.
// Also fires on 'user' (new picker/courier registered, or a role changed)
// so the Dashboard's people counts stay live too — same callback, since
// every subscriber here just reloads its own data wholesale on any change.
export function subscribeToOrderEvents(onOrderChange) {
  const token = getToken()
  if (!token) return () => {}
  const es = new EventSource(`${BASE}/events?token=${encodeURIComponent(token)}`)
  es.addEventListener('order', () => onOrderChange())
  es.addEventListener('user', () => onOrderChange())
  return () => es.close()
}

export const api = {
  login: (email, password) => request('POST', '/auth/login', { email, password }),

  getProducts: (params = {}) => {
    const q = new URLSearchParams(params).toString()
    return request('GET', `/products${q ? '?' + q : ''}`)
  },
  getLowStockProducts: () => request('GET', '/products/low-stock'),
  createProduct: (data) => request('POST', '/products', data),
  updateProduct: (id, data) => request('PUT', `/products/${id}`, data),
  deleteProduct: (id) => request('DELETE', `/products/${id}`),

  getCategories: () => request('GET', '/categories'),
  createCategory: (data) => request('POST', '/categories', data),
  updateCategory: (id, data) => request('PUT', `/categories/${id}`, data),
  deleteCategory: (id) => request('DELETE', `/categories/${id}`),

  getOrders: () => request('GET', '/orders'),
  updateOrderStatus: (id, status, extra = {}) => request('PATCH', `/orders/${id}/status`, { status, ...extra }),
  getOrderHistory: (id) => request('GET', `/orders/${id}/history`),

  getUsers: () => request('GET', '/users'),
  updateUserRole: (id, role) => request('PATCH', `/users/${id}/role`, { role }),
  getUserOrders: (id) => request('GET', `/users/${id}/orders`),

  getAutomation: () => request('GET', '/settings/automation'),
  saveAutomation: (data) => request('PUT', '/settings/automation', data),
  getAutomationErrors: () => request('GET', '/settings/automation-errors'),

  getEarningsSummary: () => request('GET', '/earnings/summary'),
  getEarningsRates: () => request('GET', '/earnings/rates'),
  saveEarningsRates: (data) => request('PUT', '/earnings/rates', data),
}
