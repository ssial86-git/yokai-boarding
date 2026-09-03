class_name MarketSystem
extends Node
## 회색 시장의 런타임 측 (P2-S3): 개장 판정(음기·밤), 오늘 시세, 사기(하루 재고)·팔기. 순수 계산은 MarketPrices / Market.

const KIND_BUY := "buy"
const KIND_SELL := "sell"

var _gate_ratio: float = 1.0
var _default_mult: float = 1.0
var _yin_threshold: int = 2


func _ready() -> void:
	var tuning := DataRegistry.tuning
	_gate_ratio = tuning.get_float("sell_price_ratio", _gate_ratio)
	_default_mult = tuning.get_float("market_default_sell_mult", _default_mult)
	_yin_threshold = tuning.get_int("market_yin_threshold", _yin_threshold)


## 문이 열려 있는가: 음기 짙은 날 또는 밤.
func is_open_now() -> bool:
	return MarketPrices.is_open(GameState.yin, _yin_threshold, Clock.band == Clock.Band.NIGHT)


func gate_price(item_id: String) -> int:
	return Market.unit_price(DataRegistry.get_item(item_id), _gate_ratio)


func sell_price(item_id: String) -> int:
	return MarketPrices.sell_price(
		DataRegistry.get_item(item_id), DataRegistry.get_market_price(item_id), _gate_ratio, _default_mult,
		GameState.rng.seed, GameState.day)


func buy_price(item_id: String) -> int:
	return MarketPrices.buy_price(DataRegistry.get_item(item_id), DataRegistry.get_market_price(item_id), GameState.rng.seed, GameState.day)


func stock_left(item_id: String) -> int:
	var row := DataRegistry.get_market_price(item_id)
	return MarketPrices.stock_left(row, GameState.market_bought) if row != null else 0


func buyable_rows() -> Array[MarketPriceData]:
	return MarketPrices.buyable_rows(DataRegistry.market_prices)


func sellable_ids() -> Array[String]:
	return Market.sellable_ids(GameState.inventory, DataRegistry.items)


## 한 개 산다. 낸 돈을 돌려주고 못 사면 0.
func buy(item_id: String) -> int:
	var item := DataRegistry.get_item(item_id)
	var row := DataRegistry.get_market_price(item_id)
	var price := MarketPrices.buy(GameState.inventory, item, row, GameState.market_bought, GameState.money, GameState.rng.seed, GameState.day)
	if price <= 0:
		if item != null and row != null and GameState.money < buy_price(item_id):
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
func sell(item_id: String, count: int) -> int:
	var price := sell_price(item_id)
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
