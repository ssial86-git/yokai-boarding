class_name MarketMenu
extends ListMenu
## 상점 메뉴 (P2-S3 회색 시장, P3-S2 마을 잡화점·약방): 위에 사기(하루 재고·오늘 구매가), 아래 팔기(오늘 시세와 대문간 대비).
## 어느 상점인지는 open(shop_id, npc_id) 로 정한다. 규칙은 MarketSystem.

var market_system: MarketSystem
var shop_id: String = MarketSystem.SHOP_GRAY
var _npc_id: String = ""


func _ready() -> void:
	super()
	Events.item_added.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.item_removed.connect(func(_id: String, _count: int) -> void: _refresh_if_open())
	Events.money_changed.connect(func(_amount: int) -> void: _refresh_if_open())


func open(new_shop_id: String = MarketSystem.SHOP_GRAY, npc_id: String = "gray_merchant") -> void:
	shop_id = new_shop_id
	_npc_id = npc_id
	open_with_title(DataRegistry.text("ui_shop_title", {
		"shop": DataRegistry.text("shop_%s" % shop_id),
		"npc": DataRegistry.speaker_name(npc_id),
		"weather": DataRegistry.weather_name(GameState.weather),
		"yin": DataRegistry.text("yin_level_%d" % clampi(GameState.yin, WeatherRoll.YIN_MIN, WeatherRoll.YIN_MAX))}))
	refresh()


func refresh() -> void:
	clear_rows()
	if market_system == null:
		return
	add_header(DataRegistry.text("ui_market_buy_header"))
	for row in market_system.buyable_rows(shop_id):
		var name := DataRegistry.item_name(row.item_id)
		var left := market_system.stock_left(row.item_id, shop_id)
		if left <= 0:
			add_row(DataRegistry.text("ui_market_sold_out", {"name": name}))
			continue
		var price := market_system.buy_price(row.item_id, shop_id)
		var item_id := row.item_id
		add_row(DataRegistry.text("ui_market_buy_row", {"name": name, "price": price, "stock": left}),
			DataRegistry.text("ui_market_buy"), func() -> void: market_system.buy(item_id, shop_id), GameState.money >= price)
	add_header(DataRegistry.text("ui_market_sell_header"))
	var ids := market_system.sellable_ids()
	if ids.is_empty():
		add_row(DataRegistry.text("ui_nothing_to_sell"))
	for item_id in ids:
		var count := GameState.inventory.get_count(item_id)
		var price := market_system.sell_price(item_id, shop_id)
		var text := DataRegistry.text("ui_market_sell_row", {
			"name": DataRegistry.item_name(item_id), "count": count, "price": price,
			"delta": _delta_text(price, market_system.gate_price(item_id))})
		var id := item_id
		add_row(text, DataRegistry.text("ui_sell_all", {"name": DataRegistry.item_name(item_id), "total": price * count}),
			func() -> void: market_system.sell(id, GameState.inventory.get_count(id), shop_id))


func _delta_text(price: int, gate: int) -> String:
	if gate <= 0 or price == gate:
		return DataRegistry.text("ui_market_delta_same")
	var percent := roundi(float(price - gate) / float(gate) * 100.0)
	return DataRegistry.text("ui_market_delta_up" if percent > 0 else "ui_market_delta_down", {"percent": percent})


func _refresh_if_open() -> void:
	if visible:
		refresh()
