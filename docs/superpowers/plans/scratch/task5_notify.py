from dx import login, api
login()

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
