import json, urllib.parse
from dx import login, api

login()

flow = api("POST", "/flows", {
    "name": "Возврат заказа курьером",
    "icon": "assignment_return", "color": "#FFA439",
    "description": "Курьер отказывается от взятого заказа: заказ возвращается в свободные, пишется запись в журнал. Курьер определяется по авторизации, не по телу запроса.",
    "status": "active", "accountability": "all",
    "trigger": "webhook", "options": {"method": "POST", "return": "$last"},
})["data"]
FID = flow["id"]
print("FLOW_ID =", FID)

read_courier = api("POST", "/operations", {
    "flow": FID, "key": "read_courier", "type": "item-read", "name": "Курьер по авторизации",
    "position_x": 19, "position_y": 1,
    "options": {"collection": "customers", "permissions": "$full",
                "query": {"filter": {"directus_user": {"_eq": "{{$accountability.user}}"}},
                          "fields": ["id", "role"]}},
})["data"]

read_order = api("POST", "/operations", {
    "flow": FID, "key": "read_order", "type": "item-read", "name": "Заказ",
    "position_x": 37, "position_y": 1,
    "options": {"collection": "orders", "permissions": "$full",
                "query": {"filter": {"id": {"_eq": "{{$trigger.body.order_id}}"}},
                          "fields": ["id", "order_status", "points_amount",
                                     "courierId.item:customers.id"]}},
})["data"]

read_returns = api("POST", "/operations", {
    "flow": FID, "key": "read_returns", "type": "item-read", "name": "Возвраты за сутки",
    "position_x": 55, "position_y": 1,
    "options": {"collection": "order_returns", "permissions": "$full",
                "query": {"filter": {"courier_id": {"_eq": "{{read_courier[0].id}}"},
                                     "date_created": {"_gte": "$NOW(-1 day)"}},
                          "fields": ["id"], "limit": -1}},
})["data"]

read_settings = api("POST", "/operations", {
    "flow": FID, "key": "read_settings", "type": "item-read", "name": "Лимит",
    "position_x": 73, "position_y": 1,
    "options": {"collection": "app_settings", "permissions": "$full",
                "query": {"fields": ["courier_returns_per_day"], "limit": 1}},
})["data"]

validate = api("POST", "/operations", {
    "flow": FID, "key": "validate", "type": "exec", "name": "Проверки",
    "position_x": 91, "position_y": 1,
    "options": {"code": """module.exports = async function (data) {
  const courier = (data.read_courier || [])[0];
  const order = (data.read_order || [])[0];
  const returns = data.read_returns || [];
  const settings = (data.read_settings || [])[0] || {};

  const limit = Number(settings.courier_returns_per_day ?? 2);
  const used = Array.isArray(returns) ? returns.length : 0;
  const left = Math.max(0, limit - used);

  if (!courier) {
    throw new Error(JSON.stringify({ ok: false, code: 'NOT_YOUR_ORDER' }));
  }
  // Порядок важен: «заказ уже не в работе» — более точная причина, чем лимит.
  if (!order || order.order_status !== 'active') {
    throw new Error(JSON.stringify({ ok: false, code: 'ORDER_NOT_ACTIVE' }));
  }

  const assigned = (order.courierId || [])[0];
  const assignedId = assigned && assigned.item
    ? (typeof assigned.item === 'object' ? assigned.item.id : assigned.item)
    : null;
  if (String(assignedId) !== String(courier.id)) {
    throw new Error(JSON.stringify({ ok: false, code: 'NOT_YOUR_ORDER' }));
  }

  if (used >= limit) {
    throw new Error(JSON.stringify({ ok: false, code: 'LIMIT_REACHED',
                                     limit: limit, returns_left: 0 }));
  }

  return {
    courier_id: courier.id,
    order_id: order.id,
    // Списываем один возврат из остатка прямо сейчас: запись в журнал
    // создаётся следующими шагами, и пересчитывать её незачем.
    returns_left: Math.max(0, left - 1),
  };
};"""},
})["data"]

do_return = api("POST", "/operations", {
    "flow": FID, "key": "do_return", "type": "item-update", "name": "Вернуть в свободные",
    "position_x": 109, "position_y": 1,
    "options": {"collection": "orders", "permissions": "$full",
                "key": ["{{validate.order_id}}"],
                "payload": {"order_status": "published",
                            "courierId": [],
                            "courier_phone": None,
                            # Флаг снимаем, иначе следующий курьер поедет бесплатно:
                            # флоу «Списание баллов» останавливается на points_charged.
                            "points_charged": False}},
})["data"]

log_return = api("POST", "/operations", {
    "flow": FID, "key": "log_return", "type": "item-create", "name": "Запись в журнал",
    "position_x": 127, "position_y": 1,
    "options": {"collection": "order_returns", "permissions": "$full",
                "payload": {"order_id": "{{validate.order_id}}",
                            "courier_id": "{{validate.courier_id}}",
                            "reason": "{{$trigger.body.reason}}",
                            "comment": "{{$trigger.body.comment}}"}},
})["data"]

answer = api("POST", "/operations", {
    "flow": FID, "key": "answer", "type": "exec", "name": "Ответ",
    "position_x": 145, "position_y": 1,
    "options": {"code": """module.exports = async function (data) {
  return { ok: true, returns_left: data.validate.returns_left };
};"""},
})["data"]

chain = [read_courier, read_order, read_returns, read_settings,
         validate, do_return, log_return, answer]
for a, b in zip(chain, chain[1:]):
    api("PATCH", f"/operations/{a['id']}", {"resolve": b["id"]})
api("PATCH", f"/flows/{FID}", {"operation": read_courier["id"]})
print("цепочка собрана")

# --- Step 4: проверка целостности цепочки ---
f = api("GET", f"/flows/{FID}?fields=id,name,status,trigger,operation")["data"]
ops = api("GET", f"/operations?filter[flow][_eq]={FID}&limit=-1&fields=id,key,resolve")["data"]
byid = {o["id"]: o for o in ops}
cur, n = f["operation"], 0
chain_report = []
while cur:
    o = byid.get(cur)
    if not o:
        chain_report.append(f"ОБРЫВ на {cur}")
        break
    n += 1
    chain_report.append(f"{n}. {o['key']}")
    cur = o["resolve"]
chain_report.append(f"шагов: {n} операций: {len(ops)} статус: {f['status']}")

# --- Step 5: проверка условий отбора отдельными запросами ---
u = api("GET", "/items/customers/268?fields=directus_user")["data"]["directus_user"]
q = urllib.parse.quote(json.dumps({"directus_user": {"_eq": u}}))
r = api("GET", f"/items/customers?fields=id&filter={q}")["data"]
step5_report = f"курьеров по directus_user: {len(r)} {json.dumps(r, ensure_ascii=False)}"

with open("task2_out.txt", "w", encoding="utf-8") as out:
    out.write(f"FLOW_ID = {FID}\n\n")
    out.write("=== Step 4: цепочка ===\n")
    out.write("\n".join(chain_report) + "\n\n")
    out.write("=== Step 5: проверка отбора ===\n")
    out.write(step5_report + "\n\n")
    out.write("=== Операции (id, key, resolve) ===\n")
    for o in ops:
        out.write(json.dumps(o, ensure_ascii=False) + "\n")

print("DONE, FLOW_ID =", FID)
