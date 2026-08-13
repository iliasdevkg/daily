import { useState, useEffect } from "react";
import { api, subscribeToOrderEvents } from "../api.js";
import Icon from "../components/Icon.jsx";

const STATUS = {
  confirmed: { label: "Подтверждён", color: "#38BDF8" },
  packing: { label: "Собирается", color: "#FB923C" },
  transit: { label: "В пути", color: "#C084FC" },
  delivered: { label: "Доставлен", color: "#33D633" },
  cancelled: { label: "Отменён", color: "#EF4444" },
};

export default function Home({ user }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null);
  const [checkedItems, setCheckedItems] = useState({});
  const [updating, setUpdating] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);

  async function load() {
    try {
      setOrders(await api.getOrders());
    } catch {
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    const unsubscribe = subscribeToOrderEvents(load);
    return unsubscribe;
  }, []);

  async function acceptOrder(order) {
    setUpdating(true);
    try {
      await api.updateStatus(order.id, "packing", user.id);
      await load();
      setSelected((prev) =>
        prev ? { ...prev, status: "packing", picker_user_id: user.id } : null,
      );
    } finally {
      setUpdating(false);
    }
  }

  async function readyOrder(order) {
    const items = order.items || [];
    const allChecked = items.every((_, i) => checkedItems[`${order.id}-${i}`]);
    if (items.length > 0 && !allChecked) {
      alert("Отметьте все товары!");
      return;
    }
    setUpdating(true);
    try {
      await api.updateStatus(order.id, "transit");
      await load();
      setSheetOpen(false);
      setSelected(null);
      setCheckedItems({});
    } finally {
      setUpdating(false);
    }
  }

  function openOrder(o) {
    setSelected(o);
    setSheetOpen(true);
  }
  function closeSheet() {
    setSheetOpen(false);
    setTimeout(() => {
      setSelected(null);
    }, 400);
  }

  function toggleItem(orderId, idx) {
    const key = `${orderId}-${idx}`;
    setCheckedItems((prev) => ({ ...prev, [key]: !prev[key] }));
  }

  const available = orders.filter(
    (o) => o.status === "confirmed" && !o.picker_user_id,
  );

  const mine = orders.filter(o => o.picker_user_id === user?.id && o.status === 'packing')
  const safePad = "max(env(safe-area-inset-top,16px),16px)";

  return (
    <>
      <div style={{ padding: `${safePad} 16px 24px` }} className="no-sb">
        <div
          style={{
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            marginBottom: 24,
          }}
        >
          <div>
            <div
              style={{
                fontSize: 12,
                color: "#FB923C",
                fontWeight: 700,
                letterSpacing: 0.8,
                textTransform: "uppercase",
                marginBottom: 4,
              }}
            >
              / сборщик
            </div>
            <div
              style={{
                fontSize: 26,
                fontWeight: 900,
                color: "#F4F4F5",
                letterSpacing: -1,
              }}
            >
              Заказы
            </div>
          </div>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 6,
              padding: "8px 14px",
              background: "rgba(251,146,60,.12)",
              borderRadius: 99,
              border: "1px solid rgba(251,146,60,.25)",
            }}
          >
            <div
              className="pulse"
              style={{
                width: 7,
                height: 7,
                borderRadius: "50%",
                background: "#FB923C",
              }}
            />
            <span style={{ fontSize: 12, fontWeight: 600, color: "#FB923C" }}>
              Онлайн
            </span>
          </div>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: 10,
            marginBottom: 24,
          }}
        >
          <StatCard
            icon="package"
            label="У меня собирается"
            value={mine.length}
            color="#FB923C"
          />
          <StatCard
            icon="bag"
            label="Новые заказы"
            value={available.length}
            color="#FBBF24"
          />
        </div>

        {mine.length > 0 && (
          <Section
            title="Собирается"
            sub={`${mine.length} заказов`}
            color="#FB923C"
          >
            {mine.map((o) => (
              <OrderCard
                key={o.id}
                order={o}
                badge="У меня"
                badgeColor="#FB923C"
                onClick={() => openOrder(o)}
              />
            ))}
          </Section>
        )}

        <Section
          title="Новые заказы"
          sub={`${available.length} заказов`}
          color="#FBBF24"
        >
          {loading ? (
            <Skeleton />
          ) : available.length === 0 ? (
            <Empty text="Нет заказов для сборки" />
          ) : (
            available.map((o) => (
              <OrderCard key={o.id} order={o} onClick={() => openOrder(o)} />
            ))
          )}
        </Section>
      </div>

      <div
        className={`sheet-bg${sheetOpen ? " open" : ""}`}
        onClick={closeSheet}
      />
      <div className={`bottom-sheet${sheetOpen ? " open" : ""}`}>
        <div
          style={{
            width: 44,
            height: 4,
            background: "rgba(255,255,255,.15)",
            borderRadius: 99,
            margin: "10px auto 0",
            flexShrink: 0,
          }}
        />
        {selected && (
          <div
            style={{ flex: 1, overflow: "auto", padding: 20 }}
            className="no-sb"
          >
            <div
              style={{
                fontSize: 12,
                color: "#FB923C",
                fontWeight: 700,
                letterSpacing: 0.6,
                textTransform: "uppercase",
                marginBottom: 6,
              }}
            >
              / заказ #{selected.id}
            </div>
            <div
              style={{
                fontSize: 22,
                fontWeight: 800,
                color: "#F4F4F5",
                marginBottom: 4,
              }}
            >
              {selected.customer_name || "Клиент"}
            </div>
            <div style={{ fontSize: 13, color: "#71717A", marginBottom: 20 }}>
              #{selected.id} ·{" "}
              {parseFloat(selected.total || 0).toLocaleString()} сом
            </div>

            {/* Items checklist */}
            {selected.items?.[0]?.name ? (
              <div style={{ marginBottom: 20 }}>
                <div
                  style={{
                    fontSize: 12,
                    color: "#71717A",
                    fontWeight: 700,
                    marginBottom: 10,
                    letterSpacing: 0.5,
                  }}
                >
                  СПИСОК ТОВАРОВ
                </div>
                {selected.items.map((item, i) => {
                  const key = `${selected.id}-${i}`;
                  const done = !!checkedItems[key];
                  return (
                    <div
                      key={i}
                      className={`check-item${done ? " done" : ""}`}
                      onClick={() => toggleItem(selected.id, i)}
                    >
                      <div className="check-box">
                        {done && (
                          <svg
                            width="20"
                            height="20"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="white"
                            strokeWidth="3"
                            strokeLinecap="round"
                            strokeLinejoin="round"
                          >
                            <polyline points="20 6 9 17 4 12" />
                          </svg>
                        )}
                      </div>
                      <div style={{ flex: 1 }}>
                        <div
                          style={{
                            fontSize: 14,
                            fontWeight: 600,
                            color: done ? "#FB923C" : "#F4F4F5",
                            textDecoration: done ? "line-through" : "none",
                          }}
                        >
                          {item.name}
                        </div>
                        <div
                          style={{
                            fontSize: 12,
                            color: "#71717A",
                            marginTop: 1,
                          }}
                        >
                          × {item.quantity} ·{" "}
                          {(item.price * item.quantity).toLocaleString()} с
                        </div>
                      </div>
                    </div>
                  );
                })}
                <div
                  style={{
                    fontSize: 12,
                    color: "#52525B",
                    marginTop: 8,
                    textAlign: "center",
                  }}
                >
                  {
                    selected.items.filter(
                      (_, i) => checkedItems[`${selected.id}-${i}`],
                    ).length
                  }{" "}
                  / {selected.items.length} собрано
                </div>
              </div>
            ) : (
              <div
                style={{ padding: "16px 0", color: "#52525B", fontSize: 13 }}
              >
                Нет товаров
              </div>
            )}

            <InfoRow icon="mapPin" label="Адрес" value={selected.address} />
            <InfoRow
              icon="phone"
              label="Телефон"
              value={selected.customer_phone || "—"}
            />
            {selected.note && (
              <InfoRow icon="pencil" label="Примечание" value={selected.note} />
            )}

            <div style={{ height: 16 }} />

            {/* Actions */}
            {selected.status === "confirmed" && !selected.picker_user_id && (
              <button
                className="btn-primary"
                onClick={() => acceptOrder(selected)}
                disabled={updating}
              >
                {updating ? "Принятие..." : (
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                    <Icon name="checkCircle" size={18} /> Начать сборку
                  </span>
                )}
              </button>
            )}
            {selected.status === "packing" &&
              selected.picker_user_id === user?.id && (
                <button
                  className="btn-primary"
                  onClick={() => readyOrder(selected)}
                  disabled={updating}
                  style={{
                    background: "linear-gradient(135deg,#33D633,#16a34a)",
                    boxShadow: "0 6px 20px rgba(51,214,51,.3)",
                  }}
                >
                  {updating ? "Обновление..." : (
                    <span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                      <Icon name="flag" size={18} /> Готово! Передать на доставку
                    </span>
                  )}
                </button>
              )}
            <div style={{ height: "env(safe-area-inset-bottom, 16px)" }} />
          </div>
        )}
      </div>
    </>
  );
}

function StatCard({ icon, label, value, color }) {
  return (
    <div className="card" style={{ padding: 16 }}>
      <Icon name={icon} size={24} color={color} style={{ marginBottom: 8 }} />
      <div style={{ fontSize: 28, fontWeight: 900, color, letterSpacing: -1 }}>
        {value}
      </div>
      <div style={{ fontSize: 11, color: "#71717A", marginTop: 2 }}>
        {label}
      </div>
    </div>
  );
}

function Section({ title, sub, color, children }) {
  return (
    <div style={{ marginBottom: 24 }}>
      <div
        style={{
          display: "flex",
          alignItems: "baseline",
          gap: 8,
          marginBottom: 12,
        }}
      >
        <div style={{ fontSize: 16, fontWeight: 800, color: "#F4F4F5" }}>
          {title}
        </div>
        <div style={{ fontSize: 12, color }}>{sub}</div>
      </div>
      {children}
    </div>
  );
}

function OrderCard({ order, badge, badgeColor, onClick }) {
  const s = STATUS[order.status] || STATUS.confirmed;
  const itemCount = order.items?.filter((i) => i.name)?.length || 0;
  return (
    <div
      className="card"
      onClick={onClick}
      style={{ padding: 16, marginBottom: 10, cursor: "pointer" }}
      onMouseDown={(e) =>
        (e.currentTarget.style.background = "rgba(255,255,255,.06)")
      }
      onMouseUp={(e) => (e.currentTarget.style.background = "")}
    >
      <div
        style={{
          display: "flex",
          alignItems: "flex-start",
          justifyContent: "space-between",
          marginBottom: 10,
        }}
      >
        <div>
          <div style={{ fontSize: 15, fontWeight: 700, color: "#F4F4F5" }}>
            {order.customer_name || `Заказ #${order.id}`}
          </div>
          <div style={{ fontSize: 12, color: "#71717A", marginTop: 2 }}>
            #{order.id} · {itemCount} товаров ·{" "}
            {parseFloat(order.total || 0).toLocaleString()} с
          </div>
        </div>
        <div
          style={{
            display: "flex",
            gap: 6,
            flexWrap: "wrap",
            justifyContent: "flex-end",
          }}
        >
          {badge && (
            <span
              style={{
                padding: "4px 10px",
                borderRadius: 99,
                background: badgeColor + "22",
                color: badgeColor,
                fontSize: 11,
                fontWeight: 700,
              }}
            >
              {badge}
            </span>
          )}
          <span
            style={{
              padding: "4px 10px",
              borderRadius: 99,
              background: s.color + "22",
              color: s.color,
              fontSize: 11,
              fontWeight: 700,
            }}
          >
            {s.label}
          </span>
        </div>
      </div>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 6,
          fontSize: 13,
          color: "#A1A1AA",
        }}
      >
        <Icon name="mapPin" size={14} color="#71717A" />
        <span
          style={{
            overflow: "hidden",
            textOverflow: "ellipsis",
            whiteSpace: "nowrap",
          }}
        >
          {order.address}
        </span>
      </div>
    </div>
  );
}

function InfoRow({ icon, label, value }) {
  return (
    <div
      style={{
        display: "flex",
        gap: 12,
        marginBottom: 14,
        alignItems: "flex-start",
      }}
    >
      <Icon name={icon} size={18} color="#71717A" style={{ marginTop: 2 }} />
      <div>
        <div
          style={{
            fontSize: 11,
            color: "#71717A",
            fontWeight: 600,
            marginBottom: 2,
          }}
        >
          {label}
        </div>
        <div style={{ fontSize: 14, color: "#F4F4F5", fontWeight: 500 }}>
          {value}
        </div>
      </div>
    </div>
  );
}

function Skeleton() {
  return [1, 2].map((i) => (
    <div
      key={i}
      className="card"
      style={{ padding: 16, marginBottom: 10, opacity: 0.4 }}
    >
      <div
        style={{
          height: 14,
          background: "rgba(255,255,255,.1)",
          borderRadius: 8,
          marginBottom: 8,
          width: "60%",
        }}
      />
      <div
        style={{
          height: 11,
          background: "rgba(255,255,255,.06)",
          borderRadius: 8,
          width: "40%",
        }}
      />
    </div>
  ));
}

function Empty({ text }) {
  return (
    <div
      style={{ textAlign: "center", padding: "40px 20px", color: "#52525B" }}
    >
      <Icon name="inbox" size={44} color="#3F3F46" style={{ marginBottom: 12 }} />
      <div style={{ fontSize: 14, fontWeight: 600 }}>{text}</div>
    </div>
  );
}
