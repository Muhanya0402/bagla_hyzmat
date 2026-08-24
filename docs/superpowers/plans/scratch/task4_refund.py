import sys
from dx import login, api
login()

flow = api("POST", "/flows", {
    "name": "Возврат жетона при отмене",
    "icon": "undo", "color": "#2ECDA7",
    "description": "Заказ отменён магазином, курьер был назначен и платил за заказ — возвращаем жетон. Курьер не виноват и уже потратил время.",
    "status": "active", "accountability": "all",
    "trigger": "event", "options": {"type": "action", "scope": ["items.update"],
                                    "collections": ["orders"]},
})["data"]
RID = flow["id"]

read_order = api("POST", "/operations", {
    "flow": RID, "key": "r_order", "type": "item-read", "name": "Заказ",
    "position_x": 19, "position_y": 1,
    "options": {"collection": "orders", "permissions": "$full",
                "query": {"filter": {"id": {"_eq": "{{$trigger.keys[0]}}"}},
                          "fields": ["id", "order_status", "courierId.item:customers.id"]}},
})["data"]

read_tx = api("POST", "/operations", {
    "flow": RID, "key": "r_tx", "type": "item-read", "name": "Транзакции по заказу",
    "position_x": 37, "position_y": 1,
    "options": {"collection": "points_transactions", "permissions": "$full",
                "query": {"filter": {"order_id": {"_some": {"item": {"_eq": "{{$trigger.keys[0]}}"}}}},
                          "fields": ["id", "type", "amount", "customer_id.item"], "limit": -1}},
})["data"]

decide = api("POST", "/operations", {
    "flow": RID, "key": "r_decide", "type": "exec", "name": "Решение",
    "position_x": 55, "position_y": 1,
    "options": {"code": """module.exports = async function (data) {
  const status = data.$trigger && data.$trigger.payload
    ? data.$trigger.payload.order_status : undefined;
  if (status !== 'canceled' && status !== 'cancelled') {
    throw new Error('Не отмена, пропускаем');
  }

  const order = (data.r_order || [])[0];
  if (!order) throw new Error('Заказ не найден, пропускаем');

  const assigned = (order.courierId || [])[0];
  const courierId = assigned && assigned.item
    ? (typeof assigned.item === 'object' ? assigned.item.id : assigned.item)
    : null;
  if (!courierId) throw new Error('Курьера не было, возвращать некому');

  const rows = data.r_tx || [];
  const own = (t) => {
    const c = (t.customer_id || [])[0];
    const id = c && c.item ? (typeof c.item === 'object' ? c.item.id : c.item) : null;
    return String(id) === String(courierId);
  };
  const debit = rows.find(t => t.type === 'debit' && own(t) && Number(t.amount) > 0);
  if (!debit) throw new Error('Списания не было, возвращать нечего');

  // Без этой проверки повторное срабатывание удвоит баланс курьера.
  const credited = rows.some(t => t.type === 'credit' && own(t));
  if (credited) throw new Error('Жетон уже возвращён');

  return { courier_id: courierId, amount: Number(debit.amount), order_id: order.id };
};"""},
})["data"]

read_courier = api("POST", "/operations", {
    "flow": RID, "key": "r_courier", "type": "item-read", "name": "Баланс курьера",
    "position_x": 73, "position_y": 1,
    "options": {"collection": "customers", "permissions": "$full",
                "query": {"filter": {"id": {"_eq": "{{r_decide.courier_id}}"}},
                          "fields": ["id", "balance_points"]}},
})["data"]

make_tx = api("POST", "/operations", {
    "flow": RID, "key": "r_credit", "type": "item-create", "name": "Начислить",
    "position_x": 91, "position_y": 1,
    "options": {"collection": "points_transactions", "permissions": "$full",
                "payload": {"customer_id": [{"item": "{{r_decide.courier_id}}",
                                             "collection": "customers"}],
                            "order_id": [{"item": "{{r_decide.order_id}}",
                                          "collection": "orders"}],
                            "amount": "{{r_decide.amount}}", "type": "credit",
                            "comment": "Возврат за отменённый заказ #{{r_decide.order_id}}"}},
})["data"]

bump = api("POST", "/operations", {
    "flow": RID, "key": "r_balance", "type": "exec", "name": "Новый баланс",
    "position_x": 109, "position_y": 1,
    "options": {"code": """module.exports = async function (data) {
  const cur = Number(((data.r_courier || [])[0] || {}).balance_points || 0);
  return { courier_id: data.r_decide.courier_id,
           new_balance: cur + Number(data.r_decide.amount) };
};"""},
})["data"]

apply_balance = api("POST", "/operations", {
    "flow": RID, "key": "r_apply", "type": "item-update", "name": "Записать баланс",
    "position_x": 127, "position_y": 1,
    "options": {"collection": "customers", "permissions": "$full",
                "key": ["{{r_balance.courier_id}}"],
                "payload": {"balance_points": "{{r_balance.new_balance}}"}},
})["data"]

chain = [read_order, read_tx, decide, read_courier, make_tx, bump, apply_balance]
for a, b in zip(chain, chain[1:]):
    api("PATCH", f"/operations/{a['id']}", {"resolve": b["id"]})
api("PATCH", f"/flows/{RID}", {"operation": read_order["id"]})

with open("task4_result.txt", "w", encoding="utf-8") as f:
    f.write("RID = " + RID + "\n")
    for o in chain:
        f.write(f"{o['key']}\t{o['id']}\n")
print("RID =", RID)
