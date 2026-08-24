# Отказ курьера от взятого заказа — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Курьер может отказаться от взятого заказа, заказ возвращается в свободные, и эта ситуация отличается от отмены магазином и отказа клиента.

**Architecture:** Возврат выполняет webhook-флоу в Directus: он определяет курьера по авторизации, проверяет владение заказом и суточный лимит, возвращает заказ в `published` и пишет запись в журнал `order_returns`. Приложение только вызывает флоу и разбирает ответ. Жетоны двигают отдельные флоу, все они смотрят на галочку `app_settings.top_up_enabled`.

**Tech Stack:** Directus 11.6.1 (flows, webhook + event triggers), Flutter/Dart 3, Dio, `flutter_test`.

## Global Constraints

- Сервер: `http://95.85.112.134:6633`. Все правки схемы и флоу — через REST API Directus.
- Политика приложения: `41e23563-ec13-4ae6-bbd5-b361f6562945`.
- Флоу «Списание баллов» списывает жетон при переходе заказа в `active`.
- У всех флоу проекта `accountability: "all"` — прогоны логируются в `directus_revisions` (`collection = directus_flows`), в `data.steps` лежат отрендеренные options каждого шага. Это основной способ отладки флоу.
- Новый статус заказа НЕ вводится: возврат — это `order_status = published`.
- Курьер в флоу определяется по `$accountability.user`, никогда по телу запроса.
- Каждое изменение проверяется `flutter analyze` (должно быть «No issues found») и `flutter test`.
- **Не собирать APK** — сборку запускает пользователь сам.
- Тексты на туркменском в этом плане — черновые, перед релизом их должен просмотреть носитель языка.

---

### Task 1: Схема в Directus

**Files:**
- Create: `docs/superpowers/plans/scratch/task1_schema.py` (одноразовый скрипт, не коммитится)

**Interfaces:**
- Produces: коллекция `order_returns` с полями `id`, `date_created`, `order_id`, `courier_id`, `reason`, `comment`; поле `app_settings.courier_returns_per_day` (integer, default 2); права `read`+`create` на `order_returns` у политики приложения.

- [ ] **Step 1: Создать коллекцию и поля**

```python
# -*- coding: utf-8 -*-
import json
from dx import login, api
login()

api("POST", "/collections", {
    "collection": "order_returns",
    "meta": {
        "icon": "assignment_return",
        "note": "Журнал отказов курьеров от взятых заказов. По нему считается суточный лимит.",
        "translations": [{"language": "ru-RU", "translation": "Отказы курьеров",
                          "singular": "Отказ", "plural": "Отказы"}],
        "sort_field": None,
    },
    "schema": {"name": "order_returns"},
    "fields": [
        {"field": "id", "type": "integer",
         "meta": {"hidden": True, "interface": "input", "readonly": True},
         "schema": {"is_primary_key": True, "has_auto_increment": True}},
    ],
})

for f in [
    {"field": "date_created", "type": "timestamp",
     "meta": {"special": ["date-created"], "interface": "datetime", "readonly": True,
              "translations": [{"language": "ru-RU", "translation": "Когда"}]},
     "schema": {}},
    {"field": "order_id", "type": "integer",
     "meta": {"interface": "input", "required": True,
              "note": "Обычное число, а не связь: запись переживает удаление заказа.",
              "translations": [{"language": "ru-RU", "translation": "Заказ"}]},
     "schema": {}},
    {"field": "reason", "type": "string",
     "meta": {"interface": "select-dropdown", "required": True,
              "options": {"choices": [
                  {"text": "Сломался транспорт", "value": "breakdown"},
                  {"text": "Заболел", "value": "illness"},
                  {"text": "Не успеваю по времени", "value": "no_time"},
                  {"text": "Другая причина", "value": "other"}]},
              "translations": [{"language": "ru-RU", "translation": "Причина"}]},
     "schema": {}},
    {"field": "comment", "type": "text",
     "meta": {"interface": "input-multiline",
              "translations": [{"language": "ru-RU", "translation": "Комментарий"}]},
     "schema": {}},
]:
    api("POST", "/fields/order_returns", f)

# courier_id — m2o на customers, чтобы в админке было видно, кто вернул
api("POST", "/fields/order_returns", {
    "field": "courier_id", "type": "integer",
    "meta": {"interface": "select-dropdown-m2o", "required": True,
             "options": {"template": "{{name}} {{surname}}"},
             "translations": [{"language": "ru-RU", "translation": "Курьер"}]},
    "schema": {},
})
api("POST", "/relations", {
    "collection": "order_returns", "field": "courier_id",
    "related_collection": "customers",
    "schema": {"on_delete": "SET NULL"},
})

api("POST", "/fields/app_settings", {
    "field": "courier_returns_per_day", "type": "integer",
    "meta": {"interface": "input", "note": "Сколько раз в сутки курьер может отказаться от взятого заказа.",
             "translations": [{"language": "ru-RU", "translation": "Отказов курьера в сутки"}]},
    "schema": {"default_value": 2},
})
api("PATCH", "/items/app_settings/1", {"courier_returns_per_day": 2})
print("схема готова")
```

- [ ] **Step 2: Выдать права приложению**

Курьер должен уметь читать свои записи (чтобы приложение показало остаток) — создавать записи будет флоу с полными правами, но право `create` тоже выдаём, чтобы админка политики выглядела последовательно.

```python
POLICY = "41e23563-ec13-4ae6-bbd5-b361f6562945"
OWN = {"courier_id": {"directus_user": {"_eq": "$CURRENT_USER"}}}
for action, flt in (("read", OWN), ("create", None)):
    api("POST", "/permissions", {
        "policy": POLICY, "collection": "order_returns",
        "action": action, "permissions": flt, "fields": ["*"],
    })
print("права выданы")
```

- [ ] **Step 3: Проверить схему**

```python
fs = api("GET", "/fields/order_returns")["data"]
print("поля:", [f["field"] for f in fs])
print("настройка:", api("GET", "/items/app_settings?fields=courier_returns_per_day")["data"])
# фильтр лимита должен отрабатывать без ошибок и на пустой таблице
import urllib.parse
q = urllib.parse.quote(json.dumps({"courier_id": {"_eq": 267},
                                   "date_created": {"_gte": "$NOW(-1 day)"}}))
print("возвратов у курьера 267 за сутки:",
      len(api("GET", f"/items/order_returns?limit=-1&fields=id&filter={q}")["data"]))
```

Ожидается: список полей содержит `order_id`, `courier_id`, `reason`, `comment`, `date_created`; настройка равна 2; счётчик возвращает 0 без ошибки.

- [ ] **Step 4: Коммит**

Схема живёт на сервере, в git попадает только запись в памяти проекта.

```bash
git commit --allow-empty -m "chore: коллекция order_returns и настройка лимита отказов в Directus"
```

---

### Task 2: Флоу «Возврат заказа курьером»

**Files:**
- Create: `docs/superpowers/plans/scratch/task2_flow.py` (одноразовый скрипт)

**Interfaces:**
- Consumes: `order_returns`, `app_settings.courier_returns_per_day` из Task 1.
- Produces: webhook-флоу; его id записывается в спеку и используется в Task 6. Ответ флоу: `{"ok": true, "returns_left": N}` либо `{"ok": false, "code": "ORDER_NOT_ACTIVE" | "NOT_YOUR_ORDER" | "LIMIT_REACHED", "returns_left": N}`.

- [ ] **Step 1: Создать флоу и шаги чтения**

```python
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
```

- [ ] **Step 2: Добавить шаг проверок**

Порядок проверок важен: сначала «заказ вообще в работе», потом «он ваш», потом лимит. Иначе курьер, у которого исчерпан лимит, увидит про лимит вместо «заказ уже отменили».

```python
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
```

- [ ] **Step 3: Добавить шаги возврата, журнала и ответа**

```python
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
```

- [ ] **Step 4: Проверить, что цепочка целая**

```python
f = api("GET", f"/flows/{FID}?fields=id,name,status,trigger,operation")["data"]
ops = api("GET", f"/operations?filter[flow][_eq]={FID}&limit=-1&fields=id,key,resolve")["data"]
byid = {o["id"]: o for o in ops}
cur, n = f["operation"], 0
while cur:
    o = byid.get(cur)
    if not o:
        print("ОБРЫВ на", cur); break
    n += 1; print(f"{n}. {o['key']}")
    cur = o["resolve"]
print("шагов:", n, "операций:", len(ops), "статус:", f["status"])
```

Ожидается: 8 шагов, 8 операций, `active`.

- [ ] **Step 5: Проверить условия отбора отдельными запросами**

Прогнать флоу целиком нельзя: `$accountability.user` требует авторизации курьера, а у нас админский токен. Поэтому проверяем те части, которые можно проверить чтением.

```python
import urllib.parse
# фильтр «курьер по directus_user» должен находить ровно одного
u = api("GET", "/items/customers/268?fields=directus_user")["data"]["directus_user"]
q = urllib.parse.quote(json.dumps({"directus_user": {"_eq": u}}))
r = api("GET", f"/items/customers?fields=id&filter={q}")["data"]
print("курьеров по directus_user:", len(r), r)
```

Ожидается: ровно 1 запись с `id = 268`.

- [ ] **Step 6: Записать id флоу в спеку и закоммитить**

Добавить в `docs/superpowers/specs/2026-08-24-otkaz-kurera-ot-zakaza-design.md` в раздел «Возврат заказа» строку вида `ID флоу: <FID>`.

```bash
git add docs/superpowers/specs/2026-08-24-otkaz-kurera-ot-zakaza-design.md
git commit -m "docs: id флоу возврата заказа в спеке"
```

---

### Task 3: Починка повторного списания жетона

**Files:**
- Create: `docs/superpowers/plans/scratch/task3_points.py` (одноразовый скрипт)

**Interfaces:**
- Consumes: шаг `do_return` из Task 2 уже снимает `points_charged`.
- Produces: флоу «Списание баллов» списывает жетон со второго курьера и не списывает дважды с одного; при выключенной галочке `top_up_enabled` не списывает вовсе.

- [ ] **Step 1: Снять текущее состояние шагов**

Перед правкой сохранить копию — на случай отката.

```python
FLOW = [f for f in api("GET", "/flows?limit=-1&fields=id,name")["data"]
        if f["name"] == "Списание баллов"][0]["id"]
ops = api("GET", f"/operations?filter[flow][_eq]={FLOW}&limit=-1&fields=id,key,type,options")["data"]
open("task3_backup.json", "w", encoding="utf-8").write(
    json.dumps(ops, ensure_ascii=False, indent=1))
print({o["key"]: o["id"] for o in ops})
```

- [ ] **Step 2: Сузить поиск транзакции до пары «заказ + курьер»**

Сейчас шаг ищет любой debit по заказу, поэтому после возврата второй курьер не платит.

```python
ldzoa = [o for o in ops if o["key"] == "item_read_ldzoa"][0]
api("PATCH", f"/operations/{ldzoa['id']}", {"options": {
    "collection": "points_transactions",
    "query": {"filter": {
        "order_id": {"_some": {"item": {"_eq": "{{$trigger.keys[0]}}"}}},
        "type": {"_eq": "debit"},
        # ← добавлено: иначе после возврата заказа второй курьер едет бесплатно
        "customer_id": {"_some": {"item": {"_eq": "{{item_read_b60iz[0].courierId[0].item}}"}}},
    }},
}})
```

- [ ] **Step 3: Добавить чтение настроек и гейт по галочке**

```python
b60iz = [o for o in ops if o["key"] == "item_read_b60iz"][0]
settings_op = api("POST", "/operations", {
    "flow": FLOW, "key": "read_settings_pts", "type": "item-read", "name": "Настройки",
    "position_x": 19, "position_y": 17,
    "options": {"collection": "app_settings", "permissions": "$full",
                "query": {"fields": ["top_up_enabled"], "limit": 1}},
})["data"]
# ставим чтение настроек ПЕРЕД чтением заказа
api("PATCH", f"/flows/{FLOW}", {"operation": settings_op["id"]})
api("PATCH", f"/operations/{settings_op['id']}", {"resolve": b60iz["id"]})
```

Затем в шаге `exec_iqkkq` в самое начало функции добавить проверку — сразу после `try {`:

```javascript
    // Жетоны выключены администратором: ничего не списываем.
    // Отбирать жетон, когда курьер не может пополнить баланс, — тупик.
    const settings = (data['read_settings_pts'] || [])[0] || {};
    if (settings.top_up_enabled === false) {
        console.log('STOP: пополнение жетонов отключено');
        return null;
    }
```

- [ ] **Step 4: Проверить, что цепочка цела**

```python
f = api("GET", f"/flows/{FLOW}?fields=operation,status")["data"]
ops2 = api("GET", f"/operations?filter[flow][_eq]={FLOW}&limit=-1&fields=id,key,resolve")["data"]
byid = {o["id"]: o for o in ops2}
cur, seen = f["operation"], []
while cur and cur not in [o["id"] for o in seen]:
    o = byid.get(cur)
    if not o: break
    seen.append(o); cur = o["resolve"]
print("цепочка:", [o["key"] for o in seen], "статус:", f["status"])
print("не в цепочке:", [o["key"] for o in ops2 if o not in seen])
```

Ожидается: первым идёт `read_settings_pts`, дальше прежняя цепочка; несвязанных операций нет.

- [ ] **Step 5: Коммит**

```bash
git commit --allow-empty -m "fix: списание жетона учитывает курьера и галочку пополнения"
```

---

### Task 4: Флоу «Возврат жетона при отмене»

**Files:**
- Create: `docs/superpowers/plans/scratch/task4_refund.py` (одноразовый скрипт)

**Interfaces:**
- Produces: event-флоу, возвращающий жетон курьеру при отмене заказа магазином.

- [ ] **Step 1: Создать флоу и шаги**

```python
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
print("RID =", RID)
```

Галочка `top_up_enabled` здесь намеренно не проверяется: возвращаем ровно то, что было списано. Если списания не было — шаг `r_decide` и так завершает флоу. Это и есть исключение из спеки: жетон, списанный до выключения галочки, возвращается.

- [ ] **Step 2: Проверить цепочку**

```python
f = api("GET", f"/flows/{RID}?fields=operation,status")["data"]
ops = api("GET", f"/operations?filter[flow][_eq]={RID}&limit=-1&fields=id,key,resolve")["data"]
byid = {o["id"]: o for o in ops}
cur, names = f["operation"], []
while cur:
    o = byid.get(cur)
    if not o: break
    names.append(o["key"]); cur = o["resolve"]
print(names, "статус:", f["status"], "операций:", len(ops))
```

Ожидается: 7 шагов, `active`.

- [ ] **Step 3: Коммит**

```bash
git commit --allow-empty -m "feat: возврат жетона курьеру при отмене заказа магазином"
```

---

### Task 5: Текст уведомления о возврате

**Files:**
- Create: `docs/superpowers/plans/scratch/task5_notify.py` (одноразовый скрипт)

**Interfaces:**
- Produces: магазин получает «Курьер отказался» вместо «Заказ создан», когда заказ возвращается в свободные.

- [ ] **Step 1: Поменять ветку `published`**

Ветка `published` во флоу «Уведомление - Изменение статуса заказа» не срабатывает никогда: флоу висит на обновлении, а создание заказа — это не обновление. Возврат — первый случай, когда заказ переходит в `published` именно обновлением.

```python
FID = "99f747ef-87d2-408b-a4a0-0104eb9f9886"
op = [o for o in api("GET", f"/operations?filter[flow][_eq]={FID}&limit=-1&fields=id,key,options")["data"]
      if o["key"] == "exec_4146o"][0]
code = op["options"]["code"]
old = """    'published': {
      title_ru: '📦 Заказ создан',
      title_tk: '📦 Sargyt döredildi',
      body_ru: 'Ваш заказ успешно создан и ожидает доставщика.',
      body_tk: 'Sargydyňyz üstünlikli döredildi we eltip beriji bekleýär.',
    },"""
new = """    // Заказ переходит в published ТОЛЬКО обновлением — то есть когда курьер
    // от него отказался. При создании заказа этот флоу не срабатывает.
    'published': {
      title_ru: '↩️ Курьер отказался',
      title_tk: '↩️ Eltip beriji ýüz öwürdi',
      body_ru: 'Курьер отказался от заказа. Заказ снова доступен другим курьерам.',
      body_tk: 'Eltip beriji sargytdan ýüz öwürdi. Sargyt ýene başga eltip berijilere elýeterli.',
    },"""
assert code.count(old) == 1, "текст ветки published изменился — сверить вручную"
api("PATCH", f"/operations/{op['id']}", {"options": {"code": code.replace(old, new, 1)}})
print("текст обновлён")
```

- [ ] **Step 2: Проверить**

```python
op2 = api("GET", f"/operations/{op['id']}?fields=options")["data"]
print("новый текст на месте:", "Курьер отказался" in op2["options"]["code"])
print("старый убран:", "Заказ создан" not in op2["options"]["code"])
```

- [ ] **Step 3: Коммит**

```bash
git commit --allow-empty -m "feat: уведомление магазину об отказе курьера от заказа"
```

---

### Task 6: Метод возврата в OrderService

**Files:**
- Modify: `lib/features/orders/order_service.dart`
- Test: `test/return_order_test.dart` (создать)

**Interfaces:**
- Consumes: webhook-флоу из Task 2 (его id).
- Produces: `enum ReturnOutcome { returned, notYourOrder, limitReached, error }`, `OrderService.returnOrder({orderId, reason, comment}) → Future<(ReturnOutcome, int)>` (исход + сколько отказов осталось), статический `OrderService.parseReturnResponse(dynamic raw) → (ReturnOutcome, int)`.

- [ ] **Step 1: Написать падающий тест**

Разбор ответа выносится в чистую функцию именно потому, что на взятии заказа мы уже обожглись: пустой ответ сервера тогда трактовался как успех, и жетоны списывались за чужой заказ.

```dart
import 'package:bagla/features/orders/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderService.parseReturnResponse', () {
    test('успешный возврат отдаёт остаток отказов', () {
      final (outcome, left) =
          OrderService.parseReturnResponse({'ok': true, 'returns_left': 1});
      expect(outcome, ReturnOutcome.returned);
      expect(left, 1);
    });

    test('чужой заказ', () {
      final (outcome, _) =
          OrderService.parseReturnResponse({'ok': false, 'code': 'NOT_YOUR_ORDER'});
      expect(outcome, ReturnOutcome.notYourOrder);
    });

    test('заказ уже не в работе трактуется как «не ваш»', () {
      final (outcome, _) =
          OrderService.parseReturnResponse({'ok': false, 'code': 'ORDER_NOT_ACTIVE'});
      expect(outcome, ReturnOutcome.notYourOrder);
    });

    test('лимит исчерпан отдаёт ноль остатка', () {
      final (outcome, left) = OrderService.parseReturnResponse(
          {'ok': false, 'code': 'LIMIT_REACHED', 'returns_left': 0});
      expect(outcome, ReturnOutcome.limitReached);
      expect(left, 0);
    });

    test('пустой или непонятный ответ НЕ считается успехом', () {
      expect(OrderService.parseReturnResponse(null).$1, ReturnOutcome.error);
      expect(OrderService.parseReturnResponse({}).$1, ReturnOutcome.error);
      expect(OrderService.parseReturnResponse('ok').$1, ReturnOutcome.error);
      expect(OrderService.parseReturnResponse({'ok': 'true'}).$1, ReturnOutcome.error);
    });

    test('ответ строкой с JSON разбирается', () {
      final (outcome, left) =
          OrderService.parseReturnResponse('{"ok":true,"returns_left":2}');
      expect(outcome, ReturnOutcome.returned);
      expect(left, 2);
    });
  });
}
```

- [ ] **Step 2: Убедиться, что тест падает**

Run: `flutter test test/return_order_test.dart`
Expected: FAIL — `ReturnOutcome` и `parseReturnResponse` не определены.

- [ ] **Step 3: Реализовать**

Добавить в `lib/features/orders/order_service.dart` рядом с `TakeOutcome`:

```dart
/// Результат попытки отказаться от взятого заказа [OrderService.returnOrder].
enum ReturnOutcome {
  /// Заказ возвращён в свободные.
  returned,

  /// Заказ уже не закреплён за этим курьером: его отменили или завершили,
  /// пока курьер думал.
  notYourOrder,

  /// Суточный лимит отказов исчерпан.
  limitReached,

  /// Сетевая или серверная ошибка. Вернулся заказ или нет — неизвестно.
  error,
}
```

И методы в класс `OrderService`:

```dart
  /// Разбор ответа флоу «Возврат заказа курьером».
  ///
  /// Вынесено в чистую функцию намеренно: на взятии заказа мы уже ошиблись,
  /// трактуя невнятный ответ сервера как успех. Всё, что не является явным
  /// `ok: true`, считается ошибкой.
  static (ReturnOutcome, int) parseReturnResponse(dynamic raw) {
    Map<String, dynamic>? body;
    if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) body = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    if (body == null) return (ReturnOutcome.error, 0);

    final left = body['returns_left'] is num
        ? (body['returns_left'] as num).toInt()
        : 0;

    if (body['ok'] == true) return (ReturnOutcome.returned, left);

    switch ((body['code'] ?? '').toString()) {
      case 'LIMIT_REACHED':
        return (ReturnOutcome.limitReached, left);
      // Для курьера обе ситуации выглядят одинаково: заказ больше не его.
      case 'NOT_YOUR_ORDER':
      case 'ORDER_NOT_ACTIVE':
        return (ReturnOutcome.notYourOrder, left);
      default:
        return (ReturnOutcome.error, left);
    }
  }

  /// Отказаться от взятого заказа: он вернётся в свободные.
  ///
  /// Курьера сервер определяет по авторизации, поэтому его id не передаём —
  /// иначе подменённый клиент вернул бы чужой заказ.
  Future<(ReturnOutcome, int)> returnOrder({
    required String orderId,
    required String reason,
    String comment = '',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/flows/trigger/<FLOW_ID_ИЗ_TASK_2>',
        data: {'order_id': orderId, 'reason': reason, 'comment': comment},
      );
      return parseReturnResponse(response.data);
    } on DioException catch (e) {
      // Флоу сообщает об отказе исключением, поэтому текст ошибки —
      // это наш же JSON с кодом причины.
      final parsed = parseReturnResponse(e.response?.data);
      if (parsed.$1 != ReturnOutcome.error) return parsed;
      final body = e.response?.data?.toString() ?? '';
      for (final code in const ['LIMIT_REACHED', 'NOT_YOUR_ORDER', 'ORDER_NOT_ACTIVE']) {
        if (body.contains(code)) {
          return parseReturnResponse({'ok': false, 'code': code, 'returns_left': 0});
        }
      }
      if (kDebugMode) print('Ошибка returnOrder: $e');
      return (ReturnOutcome.error, 0);
    } catch (e) {
      if (kDebugMode) print('Ошибка returnOrder: $e');
      return (ReturnOutcome.error, 0);
    }
  }
```

Подставить реальный id флоу из Task 2 вместо `<FLOW_ID_ИЗ_TASK_2>`.

- [ ] **Step 4: Проверить**

Run: `flutter test test/return_order_test.dart` — Expected: PASS (6 тестов)
Run: `flutter analyze` — Expected: No issues found

- [ ] **Step 5: Коммит**

```bash
git add lib/features/orders/order_service.dart test/return_order_test.dart
git commit -m "feat: метод отказа курьера от заказа и разбор ответа флоу"
```

---

### Task 7: Параметризация модалки причин

**Files:**
- Modify: `lib/features/orders/cancel_reason_modal.dart`
- Modify: `lib/features/orders/order_card.dart:346-365` (вызов модалки)
- Modify: `lib/features/orders/order_detail_screen.dart:709-725` (вызов модалки)

**Interfaces:**
- Produces: `ReasonOption({required String id, required String label, required IconData icon})` — публичный класс; `CancelReasonModal` принимает `List<ReasonOption> reasons`, `Future<bool> Function(String reasonId, String comment) onSubmit`, `String title`, `String subtitle`.

- [ ] **Step 1: Сделать `_ReasonOption` публичным**

В `cancel_reason_modal.dart` переименовать `_ReasonOption` → `ReasonOption` (класс в конце файла, и все использования внутри файла).

- [ ] **Step 2: Вынести список причин и отправку в параметры**

Заменить приватный метод `_reasons` на поле виджета и переписать `_submit`:

```dart
class CancelReasonModal extends StatefulWidget {
  final AppLocalizations words;
  final String title;
  final String subtitle;
  final List<ReasonOption> reasons;

  /// Что делать по нажатию. Возвращает `true`, если действие удалось —
  /// тогда модалка закроется. Показ ошибок остаётся на вызывающей стороне:
  /// у отмены магазином и отказа курьера они разные.
  final Future<bool> Function(String reasonId, String comment) onSubmit;

  const CancelReasonModal({
    super.key,
    required this.words,
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.onSubmit,
  });
  ...
}
```

`_submit` становится:

```dart
  Future<void> _submit() async {
    if (_selectedId == null) return;
    setState(() => _isLoading = true);
    final ok = await widget.onSubmit(_selectedId!, _commentCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) Navigator.pop(context);
  }
```

В `build` заменить `_reasons(widget.words)` на `widget.reasons`, `widget.words.cancelReasonTitle` на `widget.title`, `widget.words.cancelReasonSubtitle` на `widget.subtitle`.

- [ ] **Step 3: Обновить оба вызова отмены магазином**

В `order_card.dart` и `order_detail_screen.dart` метод `_showCancelReasonModal` теперь передаёт список и обработчик. Код одинаковый в обоих файлах:

```dart
      builder: (_) => CancelReasonModal(
        words: words,
        title: words.cancelReasonTitle,
        subtitle: words.cancelReasonSubtitle,
        reasons: [
          ReasonOption(id: 'client_refused',
              label: words.cancelReasonClientRefused, icon: Icons.person_off_outlined),
          ReasonOption(id: 'courier_late',
              label: words.cancelReasonCourierLate, icon: Icons.schedule_rounded),
          ReasonOption(id: 'wrong_address',
              label: words.cancelReasonWrongAddress, icon: Icons.wrong_location_outlined),
          ReasonOption(id: 'other',
              label: words.cancelReasonOther, icon: Icons.more_horiz_rounded),
        ],
        onSubmit: (reasonId, comment) async {
          final label = {
            'client_refused': words.cancelReasonClientRefused,
            'courier_late': words.cancelReasonCourierLate,
            'wrong_address': words.cancelReasonWrongAddress,
            'other': words.cancelReasonOther,
          }[reasonId]!;
          final outcome = await service.cancelOrderIfOpen(
            orderId,
            cancelReason: label + (comment.isNotEmpty ? ': $comment' : ''),
            shopId: currentUserId,
          );
          if (outcome == CancelOutcome.applied) {
            onUpdate?.call();
            return true;
          }
          if (context.mounted && outcome == CancelOutcome.alreadyClosed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(words.orderAlreadyClosed)),
            );
          }
          return false;
        },
      ),
```

Иконки взять те же, что стояли в удалённом методе `_reasons`.

- [ ] **Step 4: Проверить, что отмена магазином не сломалась**

Run: `flutter analyze` — Expected: No issues found
Run: `flutter test` — Expected: все тесты проходят

- [ ] **Step 5: Коммит**

```bash
git add lib/features/orders/cancel_reason_modal.dart lib/features/orders/order_card.dart lib/features/orders/order_detail_screen.dart
git commit -m "refactor: модалка причин принимает список и обработчик"
```

---

### Task 8: Кнопка отказа у курьера

**Files:**
- Modify: `lib/l10n/app_localizations.dart`, `lib/l10n/strings_ru.dart`, `lib/l10n/strings_tk.dart`
- Create: `lib/features/orders/return_order_flow.dart`
- Modify: `lib/features/orders/order_card.dart` (в `_buildActionButtons`, ветка курьера при `status == 'active'`)
- Modify: `lib/features/orders/order_detail_screen.dart` (в `_buildActionButton`, ветка `!isShop` при `status == 'active'`)

**Interfaces:**
- Consumes: `OrderService.returnOrder` (Task 6), `CancelReasonModal` с параметрами (Task 7).
- Produces: `ReturnOrderFlow.start(context, dto: OrderDto, onUpdate: VoidCallback?)`.

- [ ] **Step 1: Добавить строки локализации**

В `strings_ru.dart`:

```dart
  'returnOrder': 'Отказаться от заказа',
  'returnOrderTitle': 'Почему отказываетесь?',
  'returnOrderSubtitle': 'Заказ вернётся в свободные и станет доступен другим курьерам',
  'returnReasonBreakdown': 'Сломался транспорт',
  'returnReasonIllness': 'Плохо себя чувствую',
  'returnReasonNoTime': 'Не успеваю по времени',
  'returnOrderTokenWarning': 'Жетон за этот заказ не вернётся',
  'returnOrderDone': 'Заказ возвращён в свободные',
  'returnLimitReached': 'Лимит отказов на сегодня исчерпан',
  'returnNotYourOrder': 'Этот заказ уже не ваш',
  'returnsLeft': 'Осталось отказов сегодня: {n}',
```

В `strings_tk.dart` (черновой перевод, показать носителю языка):

```dart
  'returnOrder': 'Sargytdan ýüz öwürmek',
  'returnOrderTitle': 'Näme üçin ýüz öwürýärsiňiz?',
  'returnOrderSubtitle': 'Sargyt boş sargytlara gaýdyp barar we başga eltip berijilere elýeterli bolar',
  'returnReasonBreakdown': 'Ulag döwüldi',
  'returnReasonIllness': 'Özümi erbet duýýaryn',
  'returnReasonNoTime': 'Wagtynda ýetişemok',
  'returnOrderTokenWarning': 'Bu sargyt üçin žeton yzyna gaýtarylmaz',
  'returnOrderDone': 'Sargyt boş sargytlara gaýtaryldy',
  'returnLimitReached': 'Şu günki ýüz öwürmek çägi doldy',
  'returnNotYourOrder': 'Bu sargyt indi siziňki däl',
  'returnsLeft': 'Şu gün galan ýüz öwürmeler: {n}',
```

В `app_localizations.dart` — по геттеру на каждую строку, рядом с `orderAlreadyTaken`:

```dart
  String get returnOrder => get('returnOrder');
  String get returnOrderTitle => get('returnOrderTitle');
  String get returnOrderSubtitle => get('returnOrderSubtitle');
  String get returnReasonBreakdown => get('returnReasonBreakdown');
  String get returnReasonIllness => get('returnReasonIllness');
  String get returnReasonNoTime => get('returnReasonNoTime');
  String get returnOrderTokenWarning => get('returnOrderTokenWarning');
  String get returnOrderDone => get('returnOrderDone');
  String get returnLimitReached => get('returnLimitReached');
  String get returnNotYourOrder => get('returnNotYourOrder');
  String get returnsLeft => get('returnsLeft');
```

- [ ] **Step 2: Создать `return_order_flow.dart`**

```dart
import 'package:bagla/core/app_settings_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/orders/cancel_reason_modal.dart';
import 'package:bagla/features/orders/order_dto.dart';
import 'package:bagla/features/orders/order_service.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Отказ курьера от взятого заказа.
///
/// Всю проверку делает сервер: он же определяет курьера по авторизации,
/// сверяет, что заказ действительно его, и следит за суточным лимитом.
/// Приложение только показывает причины и разбирает ответ — по тем же
/// соображениям, по которым на сервер уехало взятие заказа.
class ReturnOrderFlow {
  ReturnOrderFlow._();

  static Future<void> start(
    BuildContext context, {
    required OrderDto dto,
    VoidCallback? onUpdate,
  }) async {
    final words = context.read<LanguageProvider>().words;
    final c = AppColors.of(context);
    final service = OrderService();

    // Предупреждение про жетон показываем, только когда он реально сгорит:
    // при выключенном пополнении и на бесплатных заказах терять нечего.
    final tokensLive = context.read<AppSettingsProvider>().topUpEnabled;
    final subtitle = (tokensLive && dto.pointsAmount > 0)
        ? '${words.returnOrderSubtitle}. ${words.returnOrderTokenWarning}'
        : words.returnOrderSubtitle;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => CancelReasonModal(
        words: words,
        title: words.returnOrderTitle,
        subtitle: subtitle,
        reasons: [
          ReasonOption(id: 'breakdown',
              label: words.returnReasonBreakdown, icon: Icons.car_repair_outlined),
          ReasonOption(id: 'illness',
              label: words.returnReasonIllness, icon: Icons.sick_outlined),
          ReasonOption(id: 'no_time',
              label: words.returnReasonNoTime, icon: Icons.schedule_rounded),
          ReasonOption(id: 'other',
              label: words.cancelReasonOther, icon: Icons.more_horiz_rounded),
        ],
        onSubmit: (reasonId, comment) async {
          final (outcome, left) = await service.returnOrder(
            orderId: dto.id, reason: reasonId, comment: comment);
          if (!sheetCtx.mounted) return outcome == ReturnOutcome.returned;

          final messenger = ScaffoldMessenger.of(sheetCtx);
          switch (outcome) {
            case ReturnOutcome.returned:
              messenger.showSnackBar(SnackBar(
                content: Text('${words.returnOrderDone}. '
                    '${words.returnsLeft.replaceAll('{n}', '$left')}',
                    style: AppText.regular(fontSize: 13)),
                behavior: SnackBarBehavior.floating,
              ));
              onUpdate?.call();
              return true;
            case ReturnOutcome.limitReached:
              _err(messenger, words.returnLimitReached, c);
              return false;
            case ReturnOutcome.notYourOrder:
              _err(messenger, words.returnNotYourOrder, c);
              onUpdate?.call();
              return false;
            case ReturnOutcome.error:
              _err(messenger, words.error, c);
              return false;
          }
        },
      ),
    );
  }

  static void _err(ScaffoldMessengerState m, String text, AppColors c) {
    m.showSnackBar(SnackBar(
      content: Text(text, style: AppText.regular(fontSize: 13, color: c.errorMuted)),
      backgroundColor: c.errorTint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }
}
```

- [ ] **Step 3: Добавить кнопку в карточку**

Ветка сейчас возвращает одну кнопку, поэтому её нужно обернуть в `Column`.
В `order_card.dart` добавить импорт `package:bagla/features/orders/return_order_flow.dart`
и заменить ветку целиком:

```dart
    if (status == 'active' && role == 'courier') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionButton(
            label: words.finishOrder,
            onTap: () => onTap?.call(),
          ),
          const SizedBox(height: 8),
          _OutlineButton(
            label: words.returnOrder,
            onTap: () => ReturnOrderFlow.start(
              context,
              dto: dto,
              onUpdate: onUpdate,
            ),
          ),
        ],
      );
    }
```

- [ ] **Step 4: Добавить кнопку в детали заказа**

Так же обернуть в `Column`. В `order_detail_screen.dart` добавить тот же импорт и заменить
ветку `if (status == 'active')` внутри `if (!isShop)`:

```dart
      if (status == 'active') {
        final double cashback = _isExpired ? 0.0 : dto.cashbackAmount;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrderPrimaryButton(
              label: cashback > 0
                  ? words.finishWithCashback.replaceAll(
                      '{cashback}',
                      '${cashback.toDouble()}',
                    )
                  : words.finishOrder,
              color: c.ink,
              filled: true,
              onTap: () => _showDeliveryCodeModal(context, orderId, service, words),
            ),
            const SizedBox(height: 10),
            OrderPrimaryButton(
              label: words.returnOrder,
              color: c.errorMuted,
              filled: false,
              // Экран не закрываем: заказ ушёл из работы, курьер сам решит,
              // куда идти дальше — а onUpdate обновит ленту под ним.
              onTap: () => ReturnOrderFlow.start(
                context,
                dto: dto,
                onUpdate: widget.onUpdate,
              ),
            ),
          ],
        );
      }
```

- [ ] **Step 5: Проверить**

Run: `flutter analyze` — Expected: No issues found
Run: `flutter test` — Expected: все тесты проходят

- [ ] **Step 6: Коммит**

```bash
git add lib/l10n lib/features/orders/return_order_flow.dart lib/features/orders/order_card.dart lib/features/orders/order_detail_screen.dart
git commit -m "feat: кнопка отказа курьера от взятого заказа"
```

---

### Task 9: Проверка на живом сервере

**Files:**
- Create: `docs/superpowers/plans/scratch/task9_verify.py` (одноразовый скрипт)

**Interfaces:**
- Consumes: всё предыдущее.

- [ ] **Step 1: Снять состояние до проверки**

```python
import json, urllib.parse
before = {
  "orders": api("GET", "/items/orders?aggregate[count]=id")["data"],
  "returns": api("GET", "/items/order_returns?aggregate[count]=id")["data"],
  "tx": api("GET", "/items/points_transactions?aggregate[count]=id")["data"],
}
print(json.dumps(before, ensure_ascii=False))
```

- [ ] **Step 2: Проверка на устройстве**

Выполняется вручную с реальной учётной записью курьера — `$accountability.user` требует его авторизации, админским токеном это не воспроизвести.

1. Курьер берёт свободный заказ.
2. Жмёт «Отказаться от заказа», выбирает причину, отправляет.
3. Ожидается: снек «Заказ возвращён в свободные, осталось отказов сегодня: N», заказ исчезает из «Моих заказов» и появляется в «Доступных».
4. Магазин получает уведомление «Курьер отказался».
5. Другой курьер берёт этот же заказ — заказ достаётся ему.

- [ ] **Step 3: Проверить следы на сервере**

```python
r = api("GET", "/items/order_returns?limit=5&sort=-id&fields=*")["data"]
print("записи журнала:", json.dumps(r, ensure_ascii=False, indent=1))

FID = "<FLOW_ID_ИЗ_TASK_2>"
q = urllib.parse.quote(json.dumps({"collection": {"_eq": "directus_flows"},
                                   "item": {"_eq": FID}}))
rev = api("GET", f"/revisions?limit=3&sort=-id&fields=id,data&filter={q}")["data"]
for x in rev:
    steps = (x.get("data") or {}).get("steps") or []
    if not steps: continue
    print(f"прогон #{x['id']}:", [(s.get("key"), s.get("status")) for s in steps])
```

Ожидается: в журнале запись с нужными `order_id`, `courier_id`, `reason`; в логе прогон, где все восемь шагов `resolve`.

- [ ] **Step 4: Проверить лимит**

Курьер отказывается от заказов подряд, пока не упрётся. На третьем (при лимите 2) ожидается сообщение «Лимит отказов на сегодня исчерпан», заказ остаётся за ним.

```python
q = urllib.parse.quote(json.dumps({"courier_id": {"_eq": <ID_КУРЬЕРА>},
                                   "date_created": {"_gte": "$NOW(-1 day)"}}))
print("возвратов за сутки:",
      len(api("GET", f"/items/order_returns?limit=-1&fields=id&filter={q}")["data"]))
```

- [ ] **Step 5: Проверить жетоны**

Включить `top_up_enabled` и поставить заказу `points_amount = 1`, затем:

1. Курьер A берёт заказ — баланс A уменьшается на 1, появляется debit.
2. A отказывается — баланс не восстанавливается (жетон сгорел), у заказа `points_charged = false`.
3. Курьер B берёт тот же заказ — **баланс B уменьшается на 1** (это и есть починка из Task 3).
4. Магазин отменяет заказ — баланс B восстанавливается, появляется credit.
5. Вернуть `top_up_enabled` в прежнее значение.

```python
q = urllib.parse.quote(json.dumps({"order_id": {"_some": {"item": {"_eq": <ID_ЗАКАЗА>}}}}))
print(json.dumps(api("GET", f"/items/points_transactions?limit=-1"
                     f"&fields=id,type,amount,customer_id.item&filter={q}")["data"],
                 ensure_ascii=False, indent=1))
```

Ожидается: два debit (у разных курьеров) и один credit у второго.

- [ ] **Step 6: Записать результат в память проекта и закоммитить**

```bash
git commit --allow-empty -m "test: проверка отказа курьера от заказа на живом сервере"
```

---

## Порядок и зависимости

Задачи 1 → 2 → 6 → 7 → 8 идут строго по порядку: каждая следующая опирается на предыдущую.
Задачи 3, 4, 5 независимы друг от друга и от 6–8, их можно делать в любой момент после Task 1.
Task 9 — последняя.
