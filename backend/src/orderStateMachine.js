// Явная карта легальных переходов статуса заказа + матрица прав на PATCH
// /orders/:id/status. Вынесено из routes/orders.js в отдельный модуль —
// сама карта используется в двух местах (валидация перехода и, в будущем,
// UI-подсказки), и как самостоятельная единица её проще проверить и
// покрыть тестами, чем разбросанную по route-хендлеру логику.

// completed и cancelled — терминальные: у них нет исходящих рёбер.
const TRANSITIONS = {
  pending:   ['confirmed', 'cancelled'],
  confirmed: ['packing', 'cancelled'],
  packing:   ['transit', 'cancelled'],
  transit:   ['delivered', 'cancelled'],
  delivered: ['completed'],
  completed: [],
  cancelled: [],
};

function isValidTransition(from, to) {
  if (from === to) return false; // повторная установка того же статуса — не переход
  return (TRANSITIONS[from] || []).includes(to);
}

// Кто имеет право переводить заказ В какой статус. admin может всё —
// проверяется отдельно в canTransition, здесь только не-админские роли.
// Matched exactly to what picker-app/delivery-app actually send today
// (picker-app/src/pages/Home.jsx: acceptOrder -> 'packing', readyOrder ->
// 'transit'; delivery-app/src/pages/Home.jsx: accept -> 'transit' (a same-
// status claim, doesn't hit this check), deliver -> 'delivered'). Neither
// app's UI has a cancel action, so granting it here would be new surface
// area, not a restriction of existing behavior — left out on purpose.
const ROLE_TRANSITIONS = {
  picker: ['packing', 'transit'],  // берёт в сборку (confirmed->packing), передаёт на доставку (packing->transit)
  delivery: ['delivered'],         // подтверждает доставку (transit->delivered)
};

// req.user.role === 'admin' обходит эту проверку целиком — обрабатывается
// вызывающей стороной (routes/orders.js), не здесь.
function roleCanSetStatus(role, toStatus) {
  return (ROLE_TRANSITIONS[role] || []).includes(toStatus);
}

// Ownership: может ли этот пользователь вообще трогать этот заказ (до
// какого статуса он его переводит — уже отдельно решает roleCanSetStatus).
// admin — всегда true, обрабатывается вызывающей стороной так же, как выше.
//
//   picker:   заказ ещё никому не отдан (claim) ИЛИ уже назначен ему
//   delivery: заказ ещё никому не отдан (claim) ИЛИ уже назначен ему
//   customer: только чтение своих заказов — сюда не попадает (нет
//             доступа к PATCH .../status в принципе, см. routes/orders.js)
function ownsOrder(role, order, userId) {
  if (role === 'picker') return order.picker_user_id == null || order.picker_user_id === userId;
  if (role === 'delivery') return order.delivery_user_id == null || order.delivery_user_id === userId;
  return false;
}

module.exports = { TRANSITIONS, isValidTransition, roleCanSetStatus, ownsOrder };
