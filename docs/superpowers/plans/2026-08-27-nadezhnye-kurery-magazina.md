# Надёжные курьеры магазина — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Магазин закрепляет за собой круг надёжных курьеров, и дорогие заказы видят только они.

**Architecture:** Коллекция `shop_trusted_couriers` хранит пары «магазин — курьер». У заказа булево `trusted_only`, которое приложение проставляет при создании по сумме. Видимость режется в четырёх местах: REST-лента, WS-лента, право `orders.update` №164 и флоу пушей. Право `orders.read` **намеренно остаётся открытым** — см. ниже.

**Tech Stack:** Directus 11.6.1 (коллекции, права, флоу), Flutter/Dart 3, Dio, `flutter_test`.

Спека: [2026-08-27-nadezhnye-kurery-magazina-design.md](../specs/2026-08-27-nadezhnye-kurery-magazina-design.md)

## Global Constraints

- Сервер: `http://95.85.112.134:6633`. Правки схемы, прав и флоу — через REST API Directus.
- Политика приложения: `41e23563-ec13-4ae6-bbd5-b361f6562945`.
- **`orders.read` (право №163) не трогаем** — решение пользователя. Следствия:
  - заказ «для своих» скрыт в приложении, но читается прямым запросом к API;
  - взять его всё равно нельзя — замок это право `orders.update` №164;
  - **фильтр пушей обязателен**: курьер вне списка не должен получить пуш, иначе он
    откроет заказ по нажатию (чтение-то открыто) и упрётся в отказ при «Взять».
- У всех флоу `accountability: "all"` — прогоны видны в `directus_revisions`
  (`GET /revisions?filter[collection][_eq]=directus_flows&filter[item][_eq]=<id>`,
  отрендеренные options в `data.steps`). Основной способ отладки.
- Новый статус заказа НЕ вводится.
- Каждое изменение проверяется `flutter analyze` («No issues found») и `flutter test`.
- **Не собирать APK** — сборку запускает пользователь сам.
- Тексты на туркменском черновые, перед релизом их смотрит носитель языка.
  Строки живут в `lib/l10n/strings_ru.dart`, `strings_tk.dart`, ключи — в `app_localizations.dart`.
- Кириллица в heredoc ломается в этой оболочке — файлы писать инструментом записи, не `cat <<`.

---

### Task 1: Схема в Directus

**Files:**
- Create: `docs/superpowers/plans/scratch/trusted_task1.py` (одноразовый скрипт, не коммитится)

**Interfaces:**
- Produces: коллекция `shop_trusted_couriers` (`id`, `shop_id`, `courier_id`, `date_created`, `added_by`); алиас `customers.trusted_couriers`; поле `orders.trusted_only`; настройка `app_settings.trusted_amount_threshold`; права политики приложения на новую коллекцию.

- [x] **Step 1: Коллекция и поля**

```python
# -*- coding: utf-8 -*-
from dx import login, api
login()

api("POST", "/collections", {
    "collection": "shop_trusted_couriers",
    "meta": {
        "icon": "verified_user",
        "note": "Курьеры, которым доверяет магазин. По этому списку режется видимость дорогих заказов.",
        "translations": [{"language": "ru-RU", "translation": "Надёжные курьеры",
                          "singular": "Надёжный курьер", "plural": "Надёжные курьеры"}],
        "sort_field": None,
    },
    "schema": {"name": "shop_trusted_couriers"},
    "fields": [
        {"field": "id", "type": "integer",
         "meta": {"hidden": True, "interface": "input", "readonly": True},
         "schema": {"is_primary_key": True, "has_auto_increment": True}},
    ],
})

api("POST", "/fields/shop_trusted_couriers", {
    "field": "date_created", "type": "timestamp",
    "meta": {"special": ["date-created"], "interface": "datetime", "readonly": True,
             "translations": [{"language": "ru-RU", "translation": "Когда"}]},
    "schema": {},
})
api("POST", "/fields/shop_trusted_couriers", {
    "field": "added_by", "type": "string",
    "meta": {"interface": "select-dropdown",
             "options": {"choices": [{"text": "Магазин", "value": "shop"},
                                     {"text": "Админ", "value": "admin"}]},
             "translations": [{"language": "ru-RU", "translation": "Кто добавил"}]},
    "schema": {"default_value": "shop"},
})
```

- [x] **Step 2: Связи с `customers` и алиас для фильтра**

`shop_id` создаётся вместе с `one_field` — так Directus сам заводит на `customers` обратный алиас `trusted_couriers`, по которому пойдёт фильтр видимости. У `courier_id` обратного алиаса нет: он не нужен и только засорил бы карточку курьера.

```python
api("POST", "/fields/shop_trusted_couriers", {
    "field": "shop_id", "type": "integer",
    "meta": {"interface": "select-dropdown-m2o", "required": True,
             "options": {"template": "{{name}} {{surname}}"},
             "translations": [{"language": "ru-RU", "translation": "Магазин"}]},
    "schema": {},
})
api("POST", "/relations", {
    "collection": "shop_trusted_couriers", "field": "shop_id",
    "related_collection": "customers",
    "meta": {"one_field": "trusted_couriers"},
    "schema": {"on_delete": "CASCADE"},
})

api("POST", "/fields/shop_trusted_couriers", {
    "field": "courier_id", "type": "integer",
    "meta": {"interface": "select-dropdown-m2o", "required": True,
             "options": {"template": "{{name}} {{surname}}"},
             "translations": [{"language": "ru-RU", "translation": "Курьер"}]},
    "schema": {},
})
api("POST", "/relations", {
    "collection": "shop_trusted_couriers", "field": "courier_id",
    "related_collection": "customers",
    "schema": {"on_delete": "CASCADE"},
})
```

`CASCADE` осознанно: удалили курьера — строка доверия к нему бессмысленна. Это отличается от `order_returns`, где `SET NULL`, потому что там запись нужна как история, а здесь — как действующее правило.

- [x] **Step 3: Поле заказа и настройка**

```python
api("POST", "/fields/orders", {
    "field": "trusted_only", "type": "boolean",
    "meta": {"interface": "boolean",
             "note": "Заказ видят только надёжные курьеры этого магазина.",
             "translations": [{"language": "ru-RU", "translation": "Только надёжные"}]},
    "schema": {"default_value": False},
})

api("POST", "/fields/app_settings", {
    "field": "trusted_amount_threshold", "type": "integer",
    "meta": {"interface": "input",
             "note": "С какой суммы заказ автоматически становится «только для надёжных». 0 — режим выключен.",
             "translations": [{"language": "ru-RU", "translation": "Порог суммы для надёжных"}]},
    "schema": {"default_value": 0},
})
```

Порог остаётся `0` (выключено) до отдельного решения — иначе функция включится в бою в момент заливки схемы. Медиана заказов сейчас 180 манат, максимум 600; разумная первая величина — 300, но ставит её пользователь.

- [x] **Step 4: Backfill — обязательно**

У 141 существующего заказа поле окажется `NULL`, а `NULL <> true` в SQL даёт не «истину». Без этого шага фильтр видимости вышвырнет из ленты вообще все старые заказы.

```python
ids = [o["id"] for o in api("GET", "/items/orders?limit=-1&fields=id")["data"]]
api("PATCH", "/items/orders", {"keys": ids, "data": {"trusted_only": False}})
nulls = api("GET", "/items/orders?limit=1&fields=id&filter[trusted_only][_null]=true")["data"]
print("заказов:", len(ids), "| осталось с NULL:", len(nulls))   # должно быть 0
```

- [x] **Step 5: Права политики приложения — ТОЛЬКО ЧТЕНИЕ**

Изначально план предполагал выдать приложению `create` и `delete` с фильтром «только свои строки». **Проверено живым запросом 27.08 — так нельзя.**

Проба: временный пользователь в политике приложения, у которого вообще нет строки в `customers` (значит, `$CURRENT_USER` не совпадает ни с одним магазином). Он вставил запись в список чужого магазина: `HTTP 204`, строка появилась в базе. Directus сверяет фильтр `create` с буквальными полями payload'а и **по связям не ходит**, поэтому условие «`shop_id` принадлежит мне» не проверяется вообще.

Последствие, если оставить как было: курьер добавляет себя в список любого магазина и забирает его дорогие заказы. Функция работала бы с обратным знаком.

Фильтр на `read` при этом проверен отдельно и **работает**: временный магазин увидел только свою строку, чужую — нет.

Поэтому приложению выдаётся одно право:

```python
POLICY = "41e23563-ec13-4ae6-bbd5-b361f6562945"
READ = {"_or": [{"shop_id":    {"directus_user": {"_eq": "$CURRENT_USER"}}},
                {"courier_id": {"directus_user": {"_eq": "$CURRENT_USER"}}}]}
api("POST", "/permissions", {
    "policy": POLICY, "collection": "shop_trusted_couriers",
    "action": "read", "permissions": READ, "fields": ["*"],
})
```

Магазин читает свой список, курьер — строки про себя (для значка «вы в надёжных»). Создание и удаление уходят в флоу — новая задача Task 2a.

- [x] **Step 6: ГЛАВНАЯ ПРОВЕРКА — глубокий фильтр**

От неё зависит вся конструкция. Путь `заказ → магазин → список → курьер` — пять уровней через M2A и o2m; проверены только три.

```python
import json, urllib.parse
shops = api("GET", "/items/customers?limit=1&fields=id&filter[role][_eq]=shop")["data"]
cours = api("GET", "/items/customers?limit=1&fields=id&filter[role][_eq]=courier")["data"]
shop_id, courier_id = shops[0]["id"], cours[0]["id"]

row = api("POST", "/items/shop_trusted_couriers",
          {"shop_id": shop_id, "courier_id": courier_id, "added_by": "admin"})["data"]
try:
    flt = {"shopId": {"item:customers": {"trusted_couriers":
              {"courier_id": {"id": {"_eq": courier_id}}}}}}
    q = urllib.parse.quote(json.dumps(flt))
    r = api("GET", f"/items/orders?limit=5&fields=id&filter={q}", soft=True)
    print("ГЛУБОКИЙ ФИЛЬТР:", "работает" if r and r.get("data") is not None else f"НЕ РАБОТАЕТ: {r}")
finally:
    api("DELETE", f"/items/shop_trusted_couriers/{row['id']}")
```

**Развилка.** Фильтр не отработал — останавливаемся и переходим на запасной вариант из спеки: поле `orders.trusted_courier_ids` (csv), которое приложение заполняет при создании заказа, и плоский фильтр по нему. Тогда меняется Task 3 и Task 6, всё остальное остаётся. Ценой того, что правка списка не влияет на уже созданные заказы.

- [x] **Step 7: Дубли в списке**

Составной UNIQUE-индекс на `(shop_id, courier_id)` через REST API Directus не ставится — нужен прямой SQL на сервере. Ставки низкие: дубль даст лишнюю строку в списке магазина, на фильтр не влияет (совпадение по «есть хотя бы один»). Поэтому защищаемся проверкой перед вставкой в Task 5, а индекс откладываем. Если дубли всё же появятся — вернуться сюда.

- [ ] **Step 8: Коммит**

```bash
git commit --allow-empty -m "chore: коллекция shop_trusted_couriers и поля для надёжных курьеров"
```

---

### Task 2: Замок — право `orders.update`

**Interfaces:**
- Consumes: `shop_trusted_couriers`, `orders.trusted_only` из Task 1.
- Produces: обновлённое право №164 — единственная настоящая защита от взятия чужого заказа.

- [x] **Step 1: Собрать и проверить выражение ДО применения**

Нынешнее право №164 (ветка «свободный заказ» пускает любого):

```json
{"_or": [
  {"courierId": {"_null": true}},
  {"courierId": {"item:customers": {"directus_user": {"_eq": "$CURRENT_USER"}}}},
  {"shopId":    {"item:customers": {"directus_user": {"_eq": "$CURRENT_USER"}}}}
]}
```

Новая первая ветка — свободный заказ И (он не «для своих» ИЛИ я в списке):

```json
{"_and": [
  {"courierId": {"_null": true}},
  {"_or": [
    {"trusted_only": {"_null": true}},
    {"trusted_only": {"_eq": false}},
    {"shopId": {"item:customers": {"trusted_couriers":
        {"courier_id": {"directus_user": {"_eq": "$CURRENT_USER"}}}}}}
  ]}
]}
```

Две ветки на `trusted_only` вместо `_neq: true` — намеренно, из-за поведения `NULL` (см. Task 1 Step 4).

Проверка подстановкой реального `directus_user` курьера, как делали с №164 в августе: посчитать, сколько заказов доступно курьеру **из списка** и **вне списка** на тестовой паре. Вне списка дорогой заказ виден быть не должен.

- [x] **Step 2: Применить**

```python
api("PATCH", "/permissions/164", {"permissions": NEW_FILTER})
```

Откат: вернуть прежнее выражение (сохранить его в файл перед правкой).

На момент применения ни у одного заказа нет `trusted_only = true`, поэтому изменение — фактически холостое. Это хорошо: замок встаёт заранее, до того как появятся заказы, которые он защищает.

- [ ] **Step 3: Живая проверка**

Взятие обычного заказа курьером должно работать как раньше. Проверяется на устройстве вместе с Task 3.

---

### Task 2a: Флоу управления списком

Появилась после пробы в Task 1 Step 5: приложению нельзя доверить создание строк напрямую. Магазин определяется **из авторизации**, а не из тела запроса — тот же приём, что в «Возврате заказа курьером».

Два отдельных webhook-флоу вместо одного с ветвлением: у операций Directus ветвление выражается через `resolve`/`reject`, и «добавить» с «убрать» в одной цепочке читались бы как ошибка. Каждый флоу линейный и отлаживается сам по себе.

**Две находки, определившие конструкцию** (обе проверены живыми запросами 27.08):

1. **Текст брошенного исключения до клиента не доходит.** `throw new Error(...)` в шаге флоу даёт клиенту `HTTP 200` с пустым телом `{}`; причина видна только в логе прогона (`validate: reject`). Поэтому коды ошибок **возвращаются**, а не бросаются: решение принимает `validate`, ветвление делает операция `condition`, и обе ветки завершаются успешно. ⚠️ То же почти наверняка касается уже сданного флоу «Возврат заказа курьером» — см. раздел «Побочная находка» в конце.
2. **Пустая подстановка в фильтр шага чтения роняет запрос в Postgres** (`22P02`, `pg_strtoint32`) вместо понятной ошибки. Поэтому шаги чтения **ничего не подставляют** в фильтры: списки крошечные (7 магазинов, 30 курьеров), читаем целиком и сопоставляем в коде.

**Флоу «Надёжный курьер — добавить»** `5ea353a4-0bed-4b99-9092-bf9b54d75a25`. Тело: `courier_id`.

`read_shop` → `read_couriers` → `read_rows` → `validate` → `gate` → `create_row` → `respond_ok`, ветка `gate.reject` → `respond_err`.

Коды: `NOT_A_SHOP`, `BAD_COURIER_ID`, `COURIER_NOT_FOUND`, `COURIER_NOT_ACTIVE`, `ALREADY_ADDED`. Проверка на дубль заменяет составной UNIQUE-индекс, который через REST не ставится (Task 1 Step 7).

**Флоу «Надёжный курьер — убрать»** `2d097a35-294b-438a-ad6d-11be583cf84b`. Тело: `courier_id`.

`read_shop` → `read_rows` → `validate` → `gate` → `delete_row` → `respond_ok`, ветка отказа та же. Код: `NOT_FOUND`. Строка ищется среди **своих**, поэтому чужую не удалить.

- [x] **Step 1: Создать оба флоу**
- [x] **Step 2: Проверить под временным пользователем**

Прогнано под настоящим входом, 7 случаев, все дали ожидаемый код:

| Случай | Ответ |
|---|---|
| пользователь без строки в `customers` | `NOT_A_SHOP`, строка не создана |
| магазин добавляет курьера | `ok:true`, `shop_id` взят из авторизации |
| он же повторно | `ALREADY_ADDED`, строк по-прежнему 1 |
| `courier_id: "abc"` | `BAD_COURIER_ID` (не сбой Postgres) |
| **чужой `shop_id` в теле запроса** | **проигнорирован**, строка ушла своему магазину |
| удалить строку чужого магазина | `NOT_FOUND`, чужая строка уцелела |
| роль сменилась на курьера | `NOT_A_SHOP` |

Все временные записи удалены.

- [x] **Step 3: Записать id флоу в спеку**

---

### Task 3: Приложение — фильтры видимости

**Files:**
- Modify: `lib/features/orders/order_service.dart` (`getOrders`)
- Modify: `lib/features/orders/order_realtime_service.dart` (`_buildFilter`)
- Create: `test/trusted_visibility_test.dart`

**Interfaces:**
- Produces: `OrderService.trustedVisibilityClause(String courierId)` — **одна** чистая функция, которую используют обе ленты.

- [x] **Step 1: Проверить, как смешиваются стили фильтров**

**Результат (27.08).** Оба стиля работают, и ключи `filter[поле][оп]` + `filter[_and][N][...]` в одном запросе **складываются по И**. Выбран третий путь, лучше обоих предложенных: выражение живёт одним вложенным объектом (`trustedVisibilityClause`), а для REST разворачивается в плоские ключи функцией `flattenFilter`. Существующие фильтры не тронуты, источник один. Двоеточие в `item:customers` работает и как есть, и закодированным (`%3A`) — Dio шлёт второй вариант.

REST-лента строит плоские ключи (`filter[order_status][_nin]`), WS-лента — вложенный JSON. Ветка `_or` в плоском виде выглядит уродливо и легко пишется с ошибкой. Прежде чем выбирать, проверить живым запросом:

1. принимает ли Directus `filter=<json>` одной строкой вместе с `limit`/`sort`/`fields`;
2. что происходит при смешении `filter[a][_eq]=x` и `filter[_and][0][b][_eq]=y` — складываются или затирают друг друга.

По результату выбрать: либо перевести `getOrders` целиком на один JSON-фильтр (чище, снимает главный риск расхождения лент, но затрагивает все существующие фильтры — район, транспорт, статусы), либо добавить только ветку доверия плоскими ключами (меньше трогаем, но дублирование остаётся).

Результат проверки записать в спеку — это решение переживёт задачу.

- [x] **Step 2: Общая функция**

Одно выражение на обе ленты — прямой ответ на риск «пять мест разъехались». Курьер знает свой `customers.id`, поэтому в приложении сравниваем по `id`, а не по `directus_user`.

```dart
/// Ветка видимости «дорогих» заказов: обычный заказ видят все, помеченный —
/// только курьеры из списка магазина.
///
/// Ровно то же выражение стоит в праве Directus №164. Если меняете здесь —
/// меняйте и там, иначе курьер увидит заказ и получит отказ при «Взять».
///
/// `trusted_only` проверяется двумя ветками, а не `_neq: true`: у заказов,
/// созданных до появления поля, там NULL, а `NULL <> true` в SQL даёт не
/// «истину» — такие заказы пропали бы из ленты целиком.
static Map<String, dynamic> trustedVisibilityClause(String courierId) => {
      '_or': [
        {'trusted_only': {'_null': true}},
        {'trusted_only': {'_eq': false}},
        {'shopId': {'item:customers': {'trusted_couriers':
            {'courier_id': {'id': {'_eq': courierId}}}}}},
      ],
    };
```

- [x] **Step 3: Вставить в обе ленты**

Только в ветку свободных заказов у роли `courier` (и в ветку «иначе» — она устроена так же). Ветка `myOrdersOnly` не трогается: взятый заказ остаётся у курьера, даже если его убрали из списка.

- [x] **Step 4: Тесты**

```dart
// Курьер из списка видит помеченный заказ; посторонний — нет; старый заказ
// с NULL виден всем (главная ловушка обратной совместимости).
```

Закрепить: три ветки `_or` присутствуют; `courierId` подставляется в путь; выражение не меняется от вызова к вызову.

- [x] **Step 5: Проверка и коммит**

`flutter analyze` — No issues found; `flutter test` — 65 прошли. На живом сервере: при одном помеченном заказе доверенный курьер видит 142, посторонний 141 — разница ровно в помеченный заказ. Тестовые пометки сняты.

```bash
flutter analyze
flutter test
git commit -m "feat: заказы «только для надёжных» скрыты от посторонних курьеров"
```

---

### Task 4: Флоу пушей

**Interfaces:**
- Consumes: `orders.trusted_only`, `shop_trusted_couriers`.
- Modifies: флоу «Уведомление - Новый заказ» `111f7b75-1d18-414e-a750-2baf1ce4c301`.

Флоу рабочий, ломать его нельзя. Поэтому **шаги вставляются, а существующие не переписываются**: `item_read_e9p2k` (все активные курьеры) остаётся как есть, а перед `exec_xqfaf` добавляется сужение списка.

- [x] **Step 1: Сохранить текущее состояние флоу**

Выгрузить все операции в файл — это план отката.

- [x] **Step 2: Шаг чтения заказа**

`item-read` по `{{$trigger.key}}`, поля `id`, `trusted_only`, `shopId.item`.

- [x] **Step 3: Шаг чтения списка магазина**

`item-read` на `shop_trusted_couriers`, фильтр по `shop_id` из предыдущего шага, поле `courier_id`. Права `$full` — как у `read_customers_fcm`.

- [x] **Step 4: Шаг сужения (exec)**

```js
module.exports = async function (data) {
  const order = data.<шаг чтения заказа>;
  const all = data.item_read_e9p2k || [];
  if (!order?.trusted_only) return { couriers: all };

  const trusted = new Set((data.<шаг чтения списка> || [])
    .map(r => Number(typeof r.courier_id === 'object' ? r.courier_id?.id : r.courier_id))
    .filter(n => !isNaN(n)));

  const couriers = all.filter(c => trusted.has(Number(c.id)));
  // Пустой список — уведомлять некого. Пусть падает явно, как уже делает
  // существующая проверка «No active couriers»: беззвучная отправка в никуда
  // неотличима от успеха, это уже кусало на отмене заказа 209.
  if (couriers.length === 0) throw new Error("Нет надёжных курьеров у магазина, пропускаем");
  return { couriers };
};
```

- [x] **Step 5: Переключить `exec_xqfaf` на суженный список**

Заменить `data.item_read_e9p2k` на результат нового шага. Это единственная правка существующего кода флоу.

- [x] **Step 6: Проверить по логам прогонов**

Прогнано на настоящих заказах, отправка пушей на время теста заглушена подменой адреса сервиса (восстановлен, проверено):

| Заказ | Уведомлений | В сервис пушей |
|---|---|---|
| обычный | 27 — все активные курьеры | ~24 (у троих нет токена) |
| «только надёжные», в списке один | **1, тот самый курьер** | ~1 |
| «только надёжные», список пуст | 0, шаг `narrow` отбивает явно | не дошло |

Тестовые заказы, уведомления и строки доверия удалены.

Создать обычный заказ — пуши уходят всем, как раньше. Затем помеченный (проставить `trusted_only` руками в админке) — в `data.steps` последнего прогона в теле запроса к push-сервису должны остаться только курьеры из списка. Тестовые заказы удалить.

---

### Task 5: Приложение — экран «Надёжные курьеры»

**Files:**
- Create: `lib/features/profile/trusted_couriers_screen.dart`
- Create: `lib/features/profile/trusted_couriers_service.dart`
- Modify: `lib/features/profile/profile_screen.dart` (пункт меню, только для `isShop`)
- Modify: `lib/main.dart` (маршрут)
- Modify: `lib/l10n/strings_ru.dart`, `strings_tk.dart`, `app_localizations.dart`

**Interfaces:**
- Produces: `list()`, `candidatesFromHistory()`, `add(courierId)`, `remove(rowId)`.

- [x] **Step 1: Сервис**

`candidatesFromHistory()` — свои заказы магазина со статусом `completed`, группировка по курьеру, счётчик доставок, сортировка по убыванию. Магазин читает собственные заказы, дополнительных прав не нужно. Уже сложившиеся пары дадут осмысленный список сразу: у магазина 278 это курьеры 280 (23 доставки) и 263 (22).

`add()` — перед вставкой проверить, нет ли уже такой пары (составного UNIQUE-индекса нет, см. Task 1 Step 7).

- [x] **Step 2: Экран**

Список надёжных с удалением. Кнопка «Добавить» открывает лист кандидатов из истории с подписью «возил у вас N раз». Пустое состояние объясняет, зачем это нужно, — иначе магазин не поймёт смысла раздела.

- [x] **Step 3: Пункт в профиле**

Рядом с существующими пунктами, под `if (auth.isShop)`.

- [x] **Step 4: Проверка и коммит**

`flutter analyze` — No issues found; `flutter test` — 71 прошли (добавлен разбор ответа флоу).

```bash
flutter analyze && flutter test
```

---

### Task 6: Приложение — включение режима при создании

**Files:**
- Modify: `lib/features/orders/create_order_screen.dart` (`_submitOrder`)
- Modify: `lib/features/orders/order_service.dart` (`createOrder`)
- Create: `test/trusted_auto_mode_test.dart`

- [x] **Step 1: Чистое правило — отдельной функцией**

```dart
/// Режим «только для надёжных» включается сам, когда заказ дорогой.
/// НО только если у магазина есть кому его отдать: иначе заказ, который
/// не открывается никому и никогда, стал бы невидим для всех навсегда,
/// причём магазин ничего для этого не нажимал.
static bool shouldBeTrustedOnly({
  required double totalAmount,
  required int threshold,        // 0 — режим выключен целиком
  required int trustedCount,
}) => threshold > 0 && trustedCount > 0 && totalAmount >= threshold;
```

Тестами закрыть: порог 0; список пуст; сумма ровно равна порогу (включается); сумма ниже.

- [x] **Step 2: Параметр `trustedOnly` в `createOrder`**

Со значением по умолчанию `false`, чтобы существующие вызовы не менялись. Кладётся в тот же payload создания заказа — **не отдельным запросом и не флоу**: флоу пушей срабатывает на создание немедленно, и при отложенной пометке рассылка всем тридцати уже уйдёт.

- [x] **Step 3: Экран создания**

- заметка «этот заказ увидят только ваши надёжные курьеры» + возможность снять на конкретном заказе;
- если сумма выше порога, а список пуст — подсказка со ссылкой на экран из Task 5.

- [x] **Step 4: Проверка и коммит**

`flutter analyze` — No issues found; `flutter test` — 78 прошли.

---

### Task 7: Значки и уведомление курьеру

**Files:**
- Modify: `lib/features/orders/order_dto.dart` (поле `trustedOnly`)
- Modify: `lib/features/orders/order_card.dart`, `lib/features/orders/order_detail_screen.dart`
- Modify: строки локализации

- [ ] **Step 1: Поле в DTO**

- [ ] **Step 2: Значок**

Магазину — «Только надёжные», чтобы он видел, почему заказ берут не сразу. Курьеру — «Надёжный заказ», чтобы понимал, почему этот заказ есть у него и нет у других.

- [ ] **Step 3 (необязательный): Уведомление о добавлении в список**

Event-флоу на создание строки в `shop_trusted_couriers`: уведомление + пуш курьеру «Магазин X добавил вас в надёжные курьеры». Ровно тот сигнал, ради которого курьер держится за магазин. Отдельный шаг, потому что это новый флоу — если поджимает время, выкидывается без ущерба для остального.

- [ ] **Step 4: Проверка и коммит**

---

### Task 8 (отдельное решение): Фото курьера магазину

Второй слой из спеки. Список даёт магазину уверенность, но от кражи не защищает — курьер из списка украдёт так же. Момент выдачи товара — единственное место, где подмену реально поймать.

Работа оказалась почти сделанной: `OrderDto.courierSelfieFileId` **уже разбирается и нигде не используется**, а строка «Курьер — Имя Фамилия» магазину уже показывается в `order_details_section.dart:198`. Нужна подмена иконки на аватар.

⚠️ **Требуется решение до реализации.** Картинки грузятся как `$baseUrl/assets/<id>` **без авторизации** (`order_images_section.dart:57`). Для фото товара это нормально, но селфи курьера — документ человека, и оно станет доступно любому, кто знает id файла. Варианты:

1. принять как есть — id угадать нельзя, риск невелик;
2. закрыть `directus_files` правами и грузить аватар с токеном — правильнее, но затрагивает и загрузку фото заказов;
3. не делать фото, оставить имя и телефон.

- [ ] **Step 1: Выбрать вариант с пользователем**
- [ ] **Step 2: Аватар в строке контрагента, только при `isShop` и непустом id, с запасной иконкой**
- [ ] **Step 3: Проверка и коммит**

---

## Порядок и безопасность выката

Задачи выстроены так, чтобы в бою ни в один момент не было половинчатого состояния:

| Этап | Что уже можно | Почему безопасно |
|---|---|---|
| Task 1 | ничего не изменилось | поля есть, никто их не читает, порог `0` |
| Task 2 | замок стоит | помеченных заказов ещё нет — правка холостая |
| Task 3–4 | ленты и пуши умеют прятать | прятать пока нечего |
| Task 5 | магазины наполняют списки | заказы всё ещё общие |
| Task 6 | пользователь ставит порог — **функция включилась** | всё готово заранее |

Порог суммы — рубильник. Пока он `0`, вся работа лежит выключенной, и включение не требует сборки приложения.

---

## Побочная находка: коды ошибок возврата заказа, похоже, не доходят

Обнаружено при постройке Task 2a, к текущей задаче отношения не имеет.

Проверено живым запросом: если шаг флоу бросает исключение, клиент получает
`HTTP 200` с пустым телом `{}`. Текст `throw new Error(...)` наружу не выходит,
причина видна только в логе прогона.

Флоу «Возврат заказа курьером» (`8544cf3e-...`) устроен ровно так же: те же
настройки (`return: "$last"`, `accountability: all`), тот же приём
`throw new Error(JSON.stringify({ ok: false, code: '...' }))` в шаге `validate`.
Значит, `OrderService.parseReturnResponse` почти наверняка получает `{}` и
скатывается в `ReturnOutcome.error` при **любом** отказе: курьер видит общую
ошибку вместо «лимит на сегодня исчерпан» или «заказ уже не ваш».

Не проверено напрямую — для этого нужен курьер с активным заказом, а трогать
боевые заказы ради проверки не стоит. Лечится тем же приёмом, что применён
здесь: `validate` возвращает решение, ветвление делает операция `condition`,
обе ветки завершаются успешно.

Отдельная задача, не входит в этот план.
