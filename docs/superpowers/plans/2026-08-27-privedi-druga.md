# «Приведи друга» — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Курьер вписывает номер друга заранее и получает 10 жетонов, когда друг довёз первый заказ.

**Architecture:** Коллекция `referrals` хранит приглашения. Четыре флоу в Directus: пригласить, отменить, связать при регистрации, выплатить. Приложение только читает свои строки и вызывает флоу — прав на запись у него нет. Все начисления построены по образцу работающего «Welcome Bonus для курьера».

**Tech Stack:** Directus 11.6.1 (коллекции, права, флоу), Flutter/Dart 3, Dio, `flutter_test`.

Спека: [2026-08-27-privedi-druga-design.md](../specs/2026-08-27-privedi-druga-design.md)

## Global Constraints

- Сервер: `http://95.85.112.134:6633`. Правки схемы, прав и флоу — через REST API Directus.
- Политика приложения: `41e23563-ec13-4ae6-bbd5-b361f6562945`.
- **Права `create`/`delete` приложению не выдаём.** Проверено 27.08: Directus не применяет
  связанный фильтр к праву `create`, и пользователь без строки в `customers` вставлял записи
  от чужого имени. Всё, что пишет, — только флоу, берущий автора из `$accountability.user`.
- **Коды ошибок возвращаются, а не бросаются.** Текст `throw new Error(...)` до клиента не
  доходит: Directus отвечает `200` с пустым телом. Решение принимает шаг `validate`,
  ветвление делает операция `condition`, обе ветки завершаются успешно.
- **Шаги чтения не подставляют в фильтр непроверенные значения.** Пустая подстановка уходит
  в Postgres сырой ошибкой `22P02`. Маленькие таблицы читаются целиком и сверяются в коде.
- Формат номера в `customers.phone` — строго `+993` + 8 цифр, без пробелов (проверено на всех
  43 записях). В приложении номер собирается как `'+993' + текст маски без пробелов` —
  тот же приём, что в `auth_provider.dart:417`.
- У всех флоу `accountability: "all"` — прогоны видны в `directus_revisions`.
- Каждое изменение проверяется `flutter analyze` («No issues found») и `flutter test`.
- **Не собирать APK** — сборку запускает пользователь сам.
- Тексты на туркменском черновые, перед релизом их смотрит носитель языка.
  Строки живут в `lib/l10n/strings_ru.dart`, `strings_tk.dart`, ключи — в `app_localizations.dart`.
- Кириллица в heredoc ломается в этой оболочке — файлы писать инструментом записи, не `cat <<`.

---

### Task 1: Схема в Directus

**Interfaces:**
- Produces: коллекция `referrals`; поля `app_settings.referral_reward` (10) и
  `referral_max_pending` (10); право `read` на `referrals` у политики приложения.

- [ ] **Step 1: Коллекция и поля**

```python
api("POST", "/collections", {
    "collection": "referrals",
    "meta": {
        "icon": "group_add",
        "note": "Приглашения курьеров. Выплата — после первой доставки приглашённого.",
        "translations": [{"language": "ru-RU", "translation": "Приглашения",
                          "singular": "Приглашение", "plural": "Приглашения"}],
        "sort_field": None,
    },
    "schema": {"name": "referrals"},
    "fields": [
        {"field": "id", "type": "integer",
         "meta": {"hidden": True, "interface": "input", "readonly": True},
         "schema": {"is_primary_key": True, "has_auto_increment": True}},
    ],
})
```

Затем поля: `date_created` (timestamp, `date-created`), `invited_phone` (string, обязательное),
`status` (string, dropdown `invited`/`registered`/`paid`, по умолчанию `invited`),
`reward_amount` (integer), `paid_at` (timestamp).

Связи `inviter_id` и `invitee_id` — m2o на `customers`, обе с `on_delete: SET NULL`:
запись должна пережить удаление участника, иначе история выплат рассыплется. Это отличается
от `shop_trusted_couriers`, где стоял `CASCADE` — там строка была действующим правилом,
здесь она журнал.

- [ ] **Step 2: Настройки**

```python
api("POST", "/fields/app_settings", {
    "field": "referral_reward", "type": "integer",
    "meta": {"interface": "input",
             "note": "Сколько жетонов получает пригласивший. 0 — программа выключена.",
             "translations": [{"language": "ru-RU", "translation": "Приз за друга"}]},
    "schema": {"default_value": 10},
})
api("POST", "/fields/app_settings", {
    "field": "referral_max_pending", "type": "integer",
    "meta": {"interface": "input",
             "note": "Сколько неоплаченных приглашений может висеть у одного курьера.",
             "translations": [{"language": "ru-RU", "translation": "Потолок приглашений"}]},
    "schema": {"default_value": 10},
})
api("PATCH", "/items/app_settings/1",
    {"referral_reward": 10, "referral_max_pending": 10})
```

Приз ставится сразу `10`: пользователь решил запускать программу не дожидаясь включения
экономики жетонов. Рубильник остаётся — ноль выключает всё.

- [ ] **Step 3: Право на чтение**

```python
READ = {"inviter_id": {"directus_user": {"_eq": "$CURRENT_USER"}}}
api("POST", "/permissions", {
    "policy": POLICY, "collection": "referrals",
    "action": "read", "permissions": READ, "fields": ["*"],
})
```

Только свои приглашения. Приглашённый своих строк не видит — ему о программе знать незачем,
и лишний повод для торга это убирает.

- [ ] **Step 4: Проверить**

Поля на месте; настройки равны 10; фильтр `inviter_id` отрабатывает на пустой таблице
без ошибки. Связанный фильтр на `read` работает — проверено 27.08 на `shop_trusted_couriers`.

- [ ] **Step 5: Коммит**

---

### Task 2: Флоу «Пригласить» и «Отменить»

**Interfaces:**
- Produces: два webhook-флоу. Ответ: `{ok: true, id: N}` либо `{ok: false, code: "..."}`.
- Коды: `NOT_A_COURIER`, `BAD_PHONE`, `SELF_INVITE`, `ALREADY_REGISTERED`,
  `ALREADY_INVITED`, `LIMIT_REACHED`, `DISABLED`.

- [ ] **Step 1: «Реферал — пригласить»**

Шаги: `read_me` → `read_customers` → `read_refs` → `read_settings` → `validate` → `gate`
→ `create_row` → `respond_ok`, ветка `gate.reject` → `respond_err`.

Читаем `customers` и `referrals` **целиком, без подстановок в фильтр** — таблицы маленькие
(43 и десятки строк), а подстановка непроверенного номера роняет запрос в Postgres.

`validate` (exec) проверяет по порядку и ничего не бросает:

```js
const me = (data.read_me || [])[0];
if (!me) return { ok: false, code: 'NOT_A_COURIER' };
if (me.role !== 'courier') return { ok: false, code: 'NOT_A_COURIER' };

const reward = Number((data.read_settings || [])[0]?.referral_reward ?? 0);
if (!(reward > 0)) return { ok: false, code: 'DISABLED' };

// Нормализация обязательна: в customers.phone формат строго +993 и 8 цифр,
// а курьер вводит номер под маской «## ## ## ##».
const digits = String(data.$trigger.body?.phone ?? '').replace(/\D/g, '');
const local = digits.length === 11 && digits.startsWith('993')
  ? digits.slice(3) : digits;
if (local.length !== 8) return { ok: false, code: 'BAD_PHONE' };
const phone = '+993' + local;

if (phone === me.phone) return { ok: false, code: 'SELF_INVITE' };

// Пригласить можно ТОЛЬКО того, кого ещё нет в системе. Иначе курьер
// перебрал бы номера чужих новичков и записал их на себя — право на
// чтение customers открыто, перебор вполне реален.
if ((data.read_customers || []).some(c => c.phone === phone)) {
  return { ok: false, code: 'ALREADY_REGISTERED' };
}

const refs = data.read_refs || [];
if (refs.some(r => r.invited_phone === phone)) {
  return { ok: false, code: 'ALREADY_INVITED' };
}

const mine = refs.filter(r => asId(r.inviter_id) === Number(me.id));
const pending = mine.filter(r => r.status !== 'paid').length;
const cap = Number((data.read_settings || [])[0]?.referral_max_pending ?? 10);
if (pending >= cap) return { ok: false, code: 'LIMIT_REACHED', limit: cap };

return { ok: true, inviter_id: me.id, phone };
```

- [ ] **Step 2: «Реферал — отменить приглашение»**

Тело: `id`. Удаляет строку только если она **своя** и в статусе `invited`.
Коды: `NOT_FOUND` (чужая, несуществующая или уже сработавшая).

Нужно, чтобы опечатка в номере не занимала место под потолком навсегда.

- [ ] **Step 3: Проверить под временным пользователем**

Та же проба, что применялась к надёжным курьерам: временный пользователь в политике
приложения. Проверить:

| Случай | Ожидание |
|---|---|
| не курьер | `NOT_A_COURIER`, строки нет |
| свой номер | `SELF_INVITE` |
| номер существующего курьера | `ALREADY_REGISTERED` |
| номер, уже кем-то приглашённый | `ALREADY_INVITED` |
| мусор вместо номера | `BAD_PHONE`, не сбой Postgres |
| номер с пробелами и через `993…` | нормализуется, строка создаётся |
| **чужой `inviter_id` в теле запроса** | **проигнорирован** |
| отмена чужой строки | `NOT_FOUND`, строка уцелела |

Все временные записи удалить.

- [ ] **Step 4: Записать id флоу в спеку, коммит**

---

### Task 3: Флоу «Связать при регистрации»

Событие `items.create` на `customers`.

- [ ] **Step 1: Создать**

Шаги: `read_new` (созданный клиент: `id`, `phone`, `role`) → `read_refs` (целиком)
→ `match` (exec) → `gate` → `link` (item-update строки: `invitee_id`, `status = registered`).

`match` ищет строку с `invited_phone === new.phone` и статусом `invited`. Не нашёл —
ветка отказа, флоу тихо заканчивается: большинство регистраций никем не приглашены,
и это норма, а не ошибка.

Роль приглашённого здесь **не проверяется**. Если друг зарегистрировался магазином, строка
просто останется в `registered` и никогда не оплатится — доставок у него не будет.

- [ ] **Step 2: Проверить**

Создать временного клиента с приглашённым номером → строка перешла в `registered`,
`invitee_id` проставлен. Создать клиента с номером, которого никто не приглашал → строк
не изменилось. Всё удалить.

- [ ] **Step 3: Коммит**

---

### Task 4: Флоу «Выплата»

Событие `items.update` на `orders`. Самое ответственное место: здесь двигаются жетоны.

- [ ] **Step 1: Создать**

Шаги: `read_order` → `guard` (exec) → `gate1` → `read_done` (завершённые доставки этого
курьера) → `read_refs` → `read_settings` → `decide` (exec) → `gate2` → `read_inviter`
→ `pay` (item-update баланса) → `log_tx` (item-create транзакции) → `mark_paid`
(item-update строки) → `notify` (item-create уведомления).

`guard` проверяет, что заказ стал `completed` и у него есть курьер, и **только после этого**
отдаёт id курьера в фильтр следующего шага — непроверенное значение в фильтр не уходит.

`decide` (exec):

```js
// Двойная защита от повторной выплаты. Флоу на items.update может
// сработать дважды, и одной проверки мало.
const done = (data.read_done || []).length;
if (done !== 1) return { ok: false, reason: 'не первая доставка' };

const row = (data.read_refs || []).find(
  r => asId(r.invitee_id) === courierId && r.status === 'registered');
if (!row) return { ok: false, reason: 'приглашения нет или уже оплачено' };

const reward = Number((data.read_settings || [])[0]?.referral_reward ?? 0);
if (!(reward > 0)) return { ok: false, reason: 'программа выключена' };

return { ok: true, row_id: row.id, inviter_id: asId(row.inviter_id), reward };
```

Сумма приза копируется в `reward_amount` строки: если завтра приз изменят, старые записи
не должны задним числом менять смысл.

- [ ] **Step 2: Проверить на живых данных**

⚠️ Проверка двигает жетоны — всё делать на временных записях и убирать за собой.

| Случай | Ожидание |
|---|---|
| приглашённый завершает **первую** доставку | +10 жетонов пригласившему, строка `paid`, уведомление |
| он же завершает вторую | ничего не меняется |
| повторное срабатывание на том же заказе | второй выплаты нет |
| доставку завершает никем не приглашённый | ничего не происходит |
| `referral_reward = 0` | выплаты нет |

Баланс пригласившего до и после сверить числом. Уведомления и заказы удалить, баланс вернуть.

- [ ] **Step 3: Коммит**

---

### Task 5: Приложение — экран «Приведи друга»

**Files:**
- Create: `lib/features/profile/referrals_service.dart`
- Create: `lib/features/profile/referrals_screen.dart`
- Modify: `lib/features/profile/profile_screen.dart` (пункт меню под `auth.isCourier`)
- Modify: `lib/main.dart` (маршрут `/referrals`)
- Modify: `lib/core/app_settings_provider.dart` (приз и потолок)
- Modify: строки локализации
- Create: `test/referrals_test.dart`

- [ ] **Step 1: Нормализация номера — чистой функцией**

```dart
/// `61 55 33 03` → `+99361553303`. Пустая строка, если номер не туркменский.
///
/// В `customers.phone` формат строго один: `+993` и 8 цифр, без пробелов.
/// Курьер вводит номер под маской, поэтому без приведения сверка молча
/// не находила бы совпадений.
static String normalizePhone(String raw)
```

Тесты: маска с пробелами; уже полный `+993…`; `993…` без плюса; лишние символы;
7 и 9 цифр → пусто; пустая строка → пусто.

- [ ] **Step 2: Сервис**

`list()` — свои строки, свежие сверху. `invite(phone)`, `cancel(rowId)` — через флоу.
`parseOutcome` — разбор кодов, как в `TrustedCouriersService`.

- [ ] **Step 3: Экран**

- шапка: сколько друзей приглашено и сколько жетонов получено;
- список со статусами «ждём регистрации» / «зарегистрировался» / «+10 жетонов»;
- крестик отмены — только у строк «ждём регистрации»;
- кнопка «Пригласить» открывает поле номера с той же маской `## ## ## ##`;
- пустое состояние объясняет **порядок**: сначала вписать номер, потом друг скачивает
  приложение. Это главное, что человек должен понять, — иначе приглашение не засчитается.

Про жетоны текст говорит честно: тратить их можно будет на заказы. Сиюминутной выгоды
не обещаем — экономика жетонов пока выключена.

- [ ] **Step 4: Пункт в профиле, маршрут, строки**

Под `auth.isCourier`, рядом с «Историей транзакций».

- [ ] **Step 5: Проверка и коммит**

```bash
flutter analyze
flutter test
```

---

### Task 6: Уведомление и сквозная проверка

- [ ] **Step 1: Иконка типа `referral_paid`**

В `notifTypeIcon` — рядом с `trusted_added`. Запасная иконка есть, но своя понятнее.

- [ ] **Step 2: Сквозной прогон**

Один сценарий целиком, на временных записях: курьер приглашает номер → «регистрируется»
клиент с этим номером → строка `registered` → он завершает первый заказ → пригласившему
+10 жетонов и уведомление. Отправка пушей на время проверки глушится подменой адреса
сервиса (и восстанавливается) — живые курьеры не должны получать уведомления о том,
чего не было.

- [ ] **Step 3: Убрать за собой и свериться**

Ноль временных заказов, клиентов, уведомлений и строк приглашений; балансы вернулись
к исходным; адрес сервиса пушей восстановлен.

- [ ] **Step 4: Коммит**

---

## Порядок выката

| Этап | Что появляется | Почему безопасно |
|---|---|---|
| Task 1 | поля и коллекция | никто их не читает |
| Task 2–4 | флоу работают | приглашений ещё нет, платить некому |
| Task 5–6 | экран у курьеров — **программа пошла** | всё проверено заранее |

В отличие от надёжных курьеров, здесь рубильник (`referral_reward`) стоит сразу в рабочем
положении: пользователь решил запускать программу немедленно. Выключить её можно тем же
числом, без пересборки.
