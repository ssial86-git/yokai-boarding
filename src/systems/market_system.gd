class_name MarketSystem
extends Node
## 상점의 런타임 측 (P2-S3 회색 시장 → P3-S2 마을 잡화점·약방): 개장 판정(회색 시장은 음기·밤), 오늘 시세, 사기(상점별 하루 재고)·팔기.
## 상점은 market_prices.csv 의 shop 컬럼으로 갈린다. 순수 계산은 MarketPrices / Market.

const KIND_BUY := "buy"
const KIND_SELL := "sell"
const SHOP_GRAY := MarketPrices.SHOP_GRAY

var _gate_ratio: float = 1.0
var _default_mult: float = 1.0
var _yin_threshold: int = 2
var _efficiency: float = 0.6
var _auto_sell_keep: int = 3
var _auto_sell_kinds: Array[String] = []


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_gate_ratio = tuning.get_float("sell_price_ratio", _gate_ratio)
	_default_mult = tuning.get_float("market_default_sell_mult", _default_mult)
	_yin_threshold = tuning.get_int("market_yin_threshold", _yin_threshold)
	_efficiency = tuning.get_float("automation_efficiency", _efficiency)
	_auto_sell_keep = tuning.get_int("auto_sell_keep", _auto_sell_keep)
	for part in tuning.get_string("auto_sell_kinds").split(";", false):
		_auto_sell_kinds.append(part.strip_edges())
	Events.day_settled.connect(func(_summary: Dictionary) -> void: auto_sell())


## 판매 위임 (P3-S4): 판매(MARKET) 슬롯의 하숙생이 저녁 정산 뒤 tuning auto_sell_kinds 종류를 종류별 auto_sell_keep 개만 남기고
## 대문간 값 × 효율로 행상에게 판다. 받은 돈을 돌려준다.
func auto_sell() -> int:
	var total_money := 0
	for yokai_id in GameState.assignment.workers_at(Assignment.MARKET):
		if not GameState.residents.has(yokai_id):
			continue
		var money := 0
		var count := 0
		for item_id: String in GameState.inventory.items().keys():
			var item := DataRegistry.get_item(item_id)
			if item == null or not _auto_sell_kinds.has(item.kind) or not Market.is_sellable(item):
				continue
			var surplus := GameState.inventory.get_count(item_id) - _auto_sell_keep
			if surplus <= 0:
				continue
			var price := maxi(int(floor(gate_price(item_id) * _efficiency + 0.5)), 1)
			if not GameState.inventory.remove(item_id, surplus):
				continue
			Events.item_removed.emit(item_id, surplus)
			money += price * surplus
			count += surplus
			Metrics.record("sell", {"item": BlessingRules.base_id(item_id), "count": surplus, "money": price * surplus})
			Events.activity_done.emit("sell", BlessingRules.base_id(item_id), surplus)
		if money > 0:
			GameState.add_money(money)
			Events.message_posted.emit(DataRegistry.text("msg_auto_sold", {
				"name": DataRegistry.yokai_name(yokai_id), "count": count, "money": money}))
		Metrics.record("delegation", {"slot": "market", "yokai": yokai_id, "amount": count})
		total_money += money
	return total_money


## 회색 시장 문이 열려 있는가: 음기 짙은 날 또는 밤.
func is_open_now() -> bool:
	return MarketPrices.is_open(GameState.yin, _yin_threshold, Clock.band == Clock.Band.NIGHT)


func gate_price(item_id: String) -> int:
	return Market.unit_price(DataRegistry.get_item(item_id), _gate_ratio)


func sell_price(item_id: String, shop_id: String = SHOP_GRAY) -> int:
	return MarketPrices.sell_price(
		DataRegistry.get_item(item_id), DataRegistry.get_market_price(item_id, shop_id), _gate_ratio, _default_mult,
		GameState.rng.seed, GameState.day)


func buy_price(item_id: String, shop_id: String = SHOP_GRAY) -> int:
	return MarketPrices.buy_price(
		DataRegistry.get_item(item_id), DataRegistry.get_market_price(item_id, shop_id), GameState.rng.seed, GameState.day)


func stock_left(item_id: String, shop_id: String = SHOP_GRAY) -> int:
	var row := DataRegistry.get_market_price(item_id, shop_id)
	return MarketPrices.stock_left(row, GameState.market_bought) if row != null else 0


func buyable_rows(shop_id: String = SHOP_GRAY) -> Array[MarketPriceData]:
	return MarketPrices.buyable_rows(DataRegistry.market_prices, shop_id)


func sellable_ids() -> Array[String]:
	return Market.sellable_ids(GameState.inventory, DataRegistry.items)


## 한 개 산다. 낸 돈을 돌려주고 못 사면 0.
func buy(item_id: String, shop_id: String = SHOP_GRAY) -> int:
	var item := DataRegistry.get_item(item_id)
	var row := DataRegistry.get_market_price(item_id, shop_id)
	var price := MarketPrices.buy(GameState.inventory, item, row, GameState.market_bought, GameState.money, GameState.rng.seed, GameState.day)
	if price <= 0:
		if item != null and row != null and GameState.money < buy_price(item_id, shop_id):
			Events.message_posted.emit(DataRegistry.text("msg_market_no_money"))
		return 0
	GameState.add_money(-price)
	Events.item_added.emit(item.id, 1)
	Events.message_posted.emit(DataRegistry.text("msg_market_bought", {"name": item.name_ko, "price": price}))
	Metrics.record("market_trade", {"kind": KIND_BUY, "item": item.id, "count": 1, "money": price})
	Events.market_traded.emit(KIND_BUY, item.id, 1, price)
	Events.activity_done.emit("buy", item.id, 1)
	return price


## count 개를 오늘 시세로 판다. 받은 돈을 돌려주고 못 팔면 0.
func sell(item_id: String, count: int, shop_id: String = SHOP_GRAY) -> int:
	var price := sell_price(item_id, shop_id)
	if price <= 0 or count <= 0 or not GameState.inventory.remove(item_id, count):
		return 0
	var money := price * count
	Events.item_removed.emit(item_id, count)
	GameState.add_money(money)
	Events.message_posted.emit(DataRegistry.text("msg_market_sold", {"name": DataRegistry.item_name(item_id), "count": count, "money": money}))
	Metrics.record("market_trade", {"kind": KIND_SELL, "item": BlessingRules.base_id(item_id), "count": count, "money": money})
	Events.market_traded.emit(KIND_SELL, item_id, count, money)
	Events.activity_done.emit("sell", BlessingRules.base_id(item_id), count)
	return money
