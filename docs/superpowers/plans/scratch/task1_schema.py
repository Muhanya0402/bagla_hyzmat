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
