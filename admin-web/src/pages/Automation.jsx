import { useState, useEffect } from 'react'
import { api } from '../api.js'
import { PageShell, Spinner } from './Dashboard.jsx'
import Icon from '../components/Icon.jsx'

const RULES = [
  {
    key: 'autoConfirm',
    icon: 'checkCircle',
    title: 'Автоподтверждение заказов',
    desc: 'Новые заказы подтверждаются мгновенно, без участия админа. Клиент сразу видит статус «Подтверждён», а заказ попадает в очередь сборки.',
    chain: 'Новый заказ → Подтверждён',
  },
  {
    key: 'autoAssignPicker',
    icon: 'package',
    title: 'Автоназначение сборщика',
    desc: 'Подтверждённый заказ автоматически назначается сборщику с наименьшим числом активных заказов — нагрузка распределяется равномерно.',
    chain: 'Подтверждён → Сборщик назначен',
  },
  {
    key: 'autoAssignDelivery',
    icon: 'bike',
    title: 'Автоназначение курьера',
    desc: 'Когда заказ собран и готов к доставке, он автоматически закрепляется за наименее загруженным курьером.',
    chain: 'Собран → Курьер назначен',
  },
  {
    key: 'autoComplete',
    icon: 'flag',
    title: 'Автозавершение доставки',
    desc: 'Через заданное время после доставки заказ автоматически переходит в «Завершён» — без действий админа.',
    chain: 'Доставлен → Завершён (по таймеру)',
  },
]

export default function Automation() {
  const [settings, setSettings] = useState(null)
  const [saving, setSaving] = useState(false)
  const [savedAt, setSavedAt] = useState(null)
  const [error, setError] = useState('')
  const [errors, setErrors] = useState([])

  function loadErrors() {
    api.getAutomationErrors().then(setErrors).catch(() => {})
  }

  useEffect(() => {
    api.getAutomation().then(setSettings).catch(e => setError(e.message))
    loadErrors()
    const interval = setInterval(loadErrors, 30000) // fail-safe: подхватываем новые сбои без перезагрузки страницы
    return () => clearInterval(interval)
  }, [])

  async function saveDelay(minutes) {
    setSaving(true)
    setError('')
    try {
      const saved = await api.saveAutomation({ completeAfterMinutes: minutes })
      setSettings(saved)
      setSavedAt(new Date())
    } catch (e) {
      setError(e.message)
    } finally {
      setSaving(false)
    }
  }

  async function toggle(key) {
    const next = { ...settings, [key]: !settings[key] }
    setSettings(next)
    setSaving(true)
    setError('')
    try {
      const saved = await api.saveAutomation({ [key]: next[key] })
      setSettings(saved)
      setSavedAt(new Date())
    } catch (e) {
      setError(e.message)
      setSettings(settings) // откат при ошибке
    } finally {
      setSaving(false)
    }
  }

  if (!settings && !error) return <PageShell title="Автоматизация"><Spinner /></PageShell>

  const allOn = settings && RULES.every(r => settings[r.key])

  return (
    <PageShell title="Автоматизация">
      {/* Итоговая полоса состояния */}
      <div className="card" style={{
        display: 'flex', alignItems: 'center', gap: 14, padding: '18px 22px', marginBottom: 20,
        background: allOn ? 'linear-gradient(135deg, #16A34A10, #33D63318)' : undefined,
        border: `1.5px solid ${allOn ? '#33D63355' : 'var(--border)'}`,
      }}>
        <div style={{
          width: 46, height: 46, borderRadius: 14, flexShrink: 0,
          background: allOn ? '#1FA83C' : '#E4E4E7',
          color: allOn ? 'white' : '#71717A',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}><Icon name="zap" size={24} /></div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 16, fontWeight: 800 }}>
            {allOn ? 'Полная автоматизация включена' : 'Автоматизация настроена частично'}
          </div>
          <div style={{ fontSize: 13, color: 'var(--text-2)' }}>
            {allOn
              ? 'Заказы проходят весь путь без ручных действий: подтверждение → сборщик → курьер.'
              : 'Включите все правила, чтобы заказы обрабатывались полностью автоматически.'}
          </div>
        </div>
        {saving && <span style={{ fontSize: 12, color: 'var(--text-3)' }}>Сохранение…</span>}
        {!saving && savedAt && (
          <span style={{ fontSize: 12, color: '#16A34A', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <Icon name="check" size={13} strokeWidth={3} /> Сохранено {savedAt.toLocaleTimeString('ru')}
          </span>
        )}
      </div>

      {error && (
        <div style={{
          background: '#EF444415', border: '1.5px solid #EF444440', color: '#B91C1C',
          borderRadius: 14, padding: '12px 16px', marginBottom: 20, fontSize: 14, fontWeight: 600,
        }}>{error}</div>
      )}

      {/* Fail-safe: непойманные ошибки автоматизации — заказ никогда не «висит» молча */}
      {errors.length > 0 && (
        <div style={{
          background: '#F59E0B12', border: '1.5px solid #F59E0B40',
          borderRadius: 16, padding: '14px 18px', marginBottom: 20,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8, color: '#B45309', fontWeight: 700, fontSize: 14 }}>
            <Icon name="alert" size={16} /> {errors.length} сбой{errors.length > 1 ? 'ев' : ''} автоматизации требует внимания
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, maxHeight: 140, overflowY: 'auto' }}>
            {errors.slice(0, 8).map(e => (
              <div key={e.id} style={{ fontSize: 12.5, color: '#92400E' }}>
                Заказ #{e.order_id} · {e.step}: {e.error_message}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Правила */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        {RULES.map(rule => (
          <div key={rule.key} className="card" style={{ display: 'flex', gap: 16, padding: 22, alignItems: 'flex-start' }}>
            <div style={{
              width: 44, height: 44, borderRadius: 12, flexShrink: 0,
              background: settings?.[rule.key] ? '#33D63322' : '#F4F4F5',
              color: settings?.[rule.key] ? '#178A31' : '#A1A1AA',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              transition: 'all 200ms',
            }}><Icon name={rule.icon} size={21} /></div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 15, fontWeight: 700, marginBottom: 4 }}>{rule.title}</div>
              <div style={{ fontSize: 13, color: 'var(--text-2)', lineHeight: 1.5, marginBottom: 8 }}>{rule.desc}</div>
              <div style={{
                display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12, fontWeight: 600,
                color: settings?.[rule.key] ? '#16A34A' : 'var(--text-3)',
                background: settings?.[rule.key] ? '#33D63315' : '#F4F4F5',
                padding: '4px 10px', borderRadius: 99,
              }}>
                {rule.chain}
              </div>
              {rule.key === 'autoComplete' && settings?.autoComplete && (
                <div style={{ marginTop: 10, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>Задержка:</span>
                  <input
                    type="number" min={1} defaultValue={settings.completeAfterMinutes}
                    onBlur={e => saveDelay(Math.max(1, Number(e.target.value) || 15))}
                    style={{ width: 64, padding: '5px 8px', border: '1.5px solid var(--border-2)', borderRadius: 8, fontSize: 13 }}
                  />
                  <span style={{ fontSize: 12.5, color: 'var(--text-2)' }}>мин после доставки</span>
                </div>
              )}
            </div>
            <Switch checked={!!settings?.[rule.key]} onChange={() => toggle(rule.key)} disabled={saving} />
          </div>
        ))}
      </div>

      {/* Как это работает */}
      <div className="card" style={{ marginTop: 20, padding: 22 }}>
        <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 10 }}>Как это работает</div>
        <ul style={{ margin: 0, paddingLeft: 18, fontSize: 13, color: 'var(--text-2)', lineHeight: 1.8 }}>
          <li>Правила срабатывают мгновенно при появлении или изменении заказа (в реальном времени, без опроса).</li>
          <li>При включении правило сразу применяется и ко всем накопившимся заказам.</li>
          <li>Сотрудник выбирается по наименьшему числу активных заказов — нагрузка распределяется честно.</li>
          <li>Ручные назначения в карточке заказа всегда имеют приоритет — автоматика никогда не перезаписывает их.</li>
        </ul>
      </div>
    </PageShell>
  )
}

function Switch({ checked, onChange, disabled }) {
  return (
    <button
      onClick={onChange}
      disabled={disabled}
      role="switch"
      aria-checked={checked}
      style={{
        width: 52, height: 30, borderRadius: 99, border: 'none', padding: 3, flexShrink: 0,
        background: checked ? '#1FA83C' : '#D4D4D8', cursor: disabled ? 'wait' : 'pointer',
        transition: 'background 200ms', position: 'relative',
      }}
    >
      <span style={{
        display: 'block', width: 24, height: 24, borderRadius: '50%', background: 'white',
        boxShadow: '0 1px 3px rgba(0,0,0,0.25)', transition: 'transform 200ms',
        transform: checked ? 'translateX(22px)' : 'translateX(0)',
      }} />
    </button>
  )
}
