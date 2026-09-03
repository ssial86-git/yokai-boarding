class_name MarketPrices
extends RefCounted
## 회색 시장 시세 순수 로직 (P2-S3). 하루 시세 = 기준가 × 배율 × (1 + swing × 그날의 흔들림[-1, 1]).
## 흔들림은 시드·날·아이템에서 파생한 RNG 라 같은 날엔 같은 값이고 방문자 RNG 를 소모하지 않는다.
## 판매 기준가는 대문간 가격(base_value × sell_price_ratio), 구매 기준가는 base_value.

const MIN_PRICE := 1


## 그날의 흔들림 [-1, 1].
static func daily_wobble(seed: int, day: int, item_id: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:market:%s" % [seed, day, item_id])
	return rng.randf_range(-1.0, 1.0)


static func _factor(row: MarketPriceData, seed: int, day: int) -> float:
	return 1.0 + row.swing * daily_wobble(seed, day, row.item_id)


## 회색 시장 판매가. 행이 없으면 대문간 가격 × default_mult.
static func sell_price(item: ItemData, row: MarketPriceData, gate_ratio: float, default_mult: float, seed: int, day: int) -> int:
	var gate := Market.unit_price(item, gate_ratio)
	if gate <= 0:
		return 0
	if row == null:
		return maxi(int(floor(gate * default_mult + 0.5)), MIN_PRICE)
	return maxi(int(floor(gate * row.sell_mult * _factor(row, seed, day) + 0.5)), MIN_PRICE)


## 구매가. 팔지 않는 아이템(buy_mult 0·재고 0)이면 0.
static func buy_price(item: ItemData, row: MarketPriceData, seed: int, day: int) -> int:
	if item == null or row == null or row.buy_mult <= 0.0 or row.stock <= 0:
		return 0
	return maxi(int(floor(item.base_value * row.buy_mult * _factor(row, seed, day) + 0.5)), MIN_PRICE)


## 오늘 살 수 있는 시세 행 (item_id 순).
static func buyable_rows(prices: Dictionary) -> Array[MarketPriceData]:
	var result: Array[MarketPriceData] = []
	for row: MarketPriceData in prices.values():
		if row.buy_mult > 0.0 and row.stock > 0:
			result.append(row)
	result.sort_custom(func(a: MarketPriceData, b: MarketPriceData) -> bool: return a.item_id < b.item_id)
	return result


## 남은 재고. bought 는 item_id -> 오늘 산 수.
static func stock_left(row: MarketPriceData, bought: Dictionary) -> int:
	return maxi(row.stock - int(bought.get(row.item_id, 0)), 0)


## 구매. 돈·재고가 되면 인벤토리에 넣고 낸 돈을 돌려준다. 안 되면 0.
static func buy(inventory: Inventory, item: ItemData, row: MarketPriceData, bought: Dictionary, money: int, seed: int, day: int) -> int:
	var price := buy_price(item, row, seed, day)
	if price <= 0 or money < price or stock_left(row, bought) <= 0:
		return 0
	inventory.add(item.id, 1)
	bought[row.item_id] = int(bought.get(row.item_id, 0)) + 1
	return price


## 문이 열리는가: 음기가 임계 이상이거나 밤.
static func is_open(yin: int, yin_threshold: int, is_night: bool) -> bool:
	return is_night or yin >= yin_threshold
