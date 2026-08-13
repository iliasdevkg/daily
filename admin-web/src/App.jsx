import { useState, useEffect } from 'react'
import Login from './pages/Login.jsx'
import Layout from './components/Layout.jsx'
import Dashboard from './pages/Dashboard.jsx'
import Products from './pages/Products.jsx'
import Categories from './pages/Categories.jsx'
import Orders from './pages/Orders.jsx'
import Users from './pages/Users.jsx'
import Automation from './pages/Automation.jsx'
import Purchasing from './pages/Purchasing.jsx'

export default function App() {
  const [token, setToken] = useState(() => localStorage.getItem('admin_token'))
  const [page, setPage] = useState('dashboard')

  useEffect(() => {
    if (token) localStorage.setItem('admin_token', token)
    else localStorage.removeItem('admin_token')
  }, [token])

  if (!token) return <Login onLogin={setToken} />

  const pages = {
    dashboard: <Dashboard />,
    products: <Products />,
    categories: <Categories />,
    purchasing: <Purchasing />,
    orders: <Orders />,
    users: <Users />,
    automation: <Automation />,
  }

  return (
    <Layout page={page} onNavigate={setPage} onLogout={() => setToken(null)}>
      {pages[page] || <Dashboard />}
    </Layout>
  )
}
